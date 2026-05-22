# AI Scoring — Pause / Resume / Clear

**Date:** 2026-05-22  
**Branch:** enhance/feedbacks  
**Status:** Approved

---

## Overview

Add three controls to the AI scoring page for a given opening:

| Control | HTTP | Route |
|---------|------|-------|
| Pause | `PATCH` | `/openings/:opening_id/ai_scores/pause` |
| Resume | `POST` | `/openings/:opening_id/ai_scores` *(existing create)* |
| Clear | `DELETE` | `/openings/:opening_id/ai_scores` |

---

## Background

`AiScoringJob` processes candidates in batches of 25 via `find_in_batches`. It acquires a per-opening PostgreSQL advisory lock, transitions `AiScoringLog#status` through `pending → processing → completed/failed`, and already calls `clear_query_cache` + `GC.compact` in its `ensure` block.

`AiScoringService#score` is fully idempotent — it reuses existing valid scores via `find_existing_valid_score`. This means "Resume" is effectively a new job run that automatically skips already-scored candidates.

---

## Feature 1 — Pause

### Trigger
`PATCH /openings/:opening_id/ai_scores/pause` →  `Opening::AiScoresController#pause`

### What happens

1. **DB flag:** Find the current in-flight log (`status: pending | processing`) for this opening and set `status = 'paused'`.
2. **Discard queued SolidQueue jobs:** Query `SolidQueue::Job` for `class_name = 'AiScoringJob'` with `finished_at: nil` and `opening_id` matching in the JSON arguments. Destroy records that have a corresponding `SolidQueue::ReadyExecution` (queued but not claimed). Skip claimed executions — those are handled by the DB flag.
3. **Running job exits gracefully:** `AiScoringJob#process_batch` checks `log.reload.status` at the top of each `find_in_batches` iteration. If `paused` or `cancelled`, it `break`s. The existing `ensure` block fires: `clear_query_cache` + `GC.compact` — memory is freed.
4. Redirect back with notice: *"Scoring paused. Resume when ready."*

### Guard
If no in-flight log exists, redirect with alert: *"No scoring run is currently in progress."*

### Authorization
`authorize @opening` (same policy as `create`).

---

## Feature 2 — Resume

### Trigger
`POST /openings/:opening_id/ai_scores` — the existing `create` action. No code change needed.

### What happens
A new `AiScoringJob` is enqueued with a fresh `batch_id`. Because `AiScoringService#score` calls `find_existing_valid_score` for every candidate, those already scored before the pause get status `:reused` and are skipped immediately. Only unscored candidates hit the AI provider.

### UI change
When `@latest_log.status == 'paused'`, the "Generate Scores" button label changes to **"Resume Scoring"** and the in-progress banner is replaced with a "Paused" banner showing progress so far.

### Guard
The existing in-flight check in `create` must also treat `paused` as **not** in-flight (so Resume is allowed). Update the check:

```ruby
in_flight = @opening.ai_scoring_logs.where(status: %w[pending processing]).exists?
```

`paused` is deliberately excluded — that's correct already.

---

## Feature 3 — Clear

### Trigger
`DELETE /openings/:opening_id/ai_scores` → `Opening::AiScoresController#destroy`

### What happens (inside a transaction)

1. **Signal running job:** If a log exists with `status: pending | processing`, update it to `cancelled`. The running job sees this on next batch boundary and exits, freeing memory via the `ensure` block.
2. **Discard queued SolidQueue jobs:** Same JSON-argument query as Pause — destroy `SolidQueue::Job` records that have a `ReadyExecution`.
3. **Delete all AiScores:** `AiScore.where(opening_id: opening.id).delete_all`
4. **Delete all AiScoringLogs:** `AiScoringLog.where(opening_id: opening.id).delete_all`
5. **Reset Opening extraction fields:** `opening.update!(must_have: [], good_to_have: [], jd_requirements_hash: nil)`

### UI
A "Clear All Scores" button on the AI scores page. Uses `data-confirm` (or a small Stimulus confirm modal) to require explicit user confirmation before submitting.

### Authorization
`authorize @opening` — same policy gate.

---

## Status Model Changes

### `AiScoringLog::STATUSES`

Add `paused` and `cancelled`:

```ruby
STATUSES = %w[pending processing completed failed paused cancelled].freeze
```

No DB migration needed — `status` is already a free-text string column.

### Job loop change (`AiScoringJob#process_batch`)

```ruby
scope.find_in_batches(batch_size: CHUNK_SIZE) do |batch|
  break if log.reload.status.in?(%w[paused cancelled])
  batch.each { |c| service.score(candidate: c, opening: opening) }
  ActiveRecord::Base.connection.clear_query_cache
  GC.compact
end

# Only mark completed if not interrupted
unless log.reload.status.in?(%w[paused cancelled])
  log.update!(status: 'completed', completed_at: Time.current)
end
```

---

## SolidQueue Job Discarding

Helper (private method in controller or extracted to a service):

```ruby
def discard_queued_ai_scoring_jobs(opening_id)
  # arguments is a text column — cast to jsonb for JSON path querying
  SolidQueue::Job
    .where(class_name: 'AiScoringJob', finished_at: nil)
    .where("(arguments::jsonb) -> 'arguments' -> 0 ->> 'opening_id' = ?", opening_id.to_s)
    .joins(:ready_execution)   # only queued-but-not-claimed (running jobs exit via DB flag)
    .destroy_all
end
```

---

## UI Summary

| State | Banner shown | Buttons shown |
|-------|-------------|---------------|
| No scores yet | Empty state | Generate Scores |
| `pending` / `processing` | Blue in-progress + progress bar | **Pause** |
| `paused` | Yellow "Paused" banner with progress | **Resume Scoring**, Clear All Scores |
| `completed` | (none / warnings if skips) | Generate Scores, **Clear All Scores** |
| `failed` | Yellow warning | Try Again, **Clear All Scores** |
| `cancelled` | Grey "Cleared" or redirected away | Generate Scores |

---

## Routing

```ruby
resources :ai_scores, only: [:index, :create, :destroy] do
  collection do
    patch :pause
  end
end
```

---

## Tests

- `Opening::AiScoresController` — `pause`, `destroy` actions (guard cases, happy path)
- `AiScoringJob` — job exits gracefully when log is `paused` or `cancelled` mid-batch
- `AiScoringLog` — `paused` and `cancelled` are valid statuses
- Integration: Clear resets opening extraction fields and deletes all scores/logs

---

## Out of Scope

- Per-candidate pause (too granular)
- Pause notification via ActionCable / WebSocket (auto-refresh every 5s already handles it)
- Audit trail of who paused/cleared (can be added later via a separate log entry)
