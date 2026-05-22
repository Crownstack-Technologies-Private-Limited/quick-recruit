# AI Scoring Pause / Resume / Clear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Pause, Resume, and Clear controls to the AI scoring page so admins can stop in-flight scoring runs, free queue and memory resources, and fully reset scores and JD extractions for a given opening.

**Architecture:** DB-flag approach — Pause sets `AiScoringLog#status` to `paused`; the running `AiScoringJob` checks that flag at each batch boundary and exits cleanly (existing `ensure` block handles `clear_query_cache` + `GC.compact`). Queued-but-not-yet-running SolidQueue jobs are destroyed via a JSON-argument query. Clear signals `cancelled`, deletes all scores and all logs for the opening, and resets the opening's `must_have`, `good_to_have`, and `jd_requirements_hash` fields. Resume reuses the existing `create` action — `AiScoringService` is already idempotent and skips previously-scored candidates.

**Tech Stack:** Rails 8, SolidQueue, Pundit, Turbo, Tailwind CSS

---

## File Map

| File | Change |
|------|--------|
| `app/models/ai_scoring_log.rb` | Add `paused`, `cancelled` to `STATUSES` |
| `app/jobs/ai_scoring_job.rb` | Add per-batch pause/cancel check; add `paused`/`cancelled` to advisory-lock skip guard |
| `config/routes.rb` | Add `destroy` + collection `patch :pause` to ai_scores resources |
| `app/controllers/opening/ai_scores_controller.rb` | Add `pause`, `destroy` actions + `discard_queued_ai_scoring_jobs` private helper |
| `app/views/opening/ai_scores/index.html.erb` | Add Pause button, Paused banner, Clear All Scores button |
| `test/models/ai_scoring_log_test.rb` | Existing status iterator test auto-covers new statuses — no new tests |
| `test/jobs/ai_scoring_job_test.rb` | 2 new tests: skip-when-already-paused, stop-at-next-batch-boundary |
| `test/controllers/opening/ai_scores_controller_test.rb` | 6 new tests: 3 for pause, 3 for destroy |

---

## Task 1: Add `paused` and `cancelled` to AiScoringLog statuses

**Files:**
- Modify: `app/models/ai_scoring_log.rb`
- Test: `test/models/ai_scoring_log_test.rb` (existing test auto-covers new values)

- [ ] **Step 1: Confirm the existing model tests pass before touching anything**

```bash
bin/rails test test/models/ai_scoring_log_test.rb
```

Expected: All green.

- [ ] **Step 2: Add the two new statuses**

In `app/models/ai_scoring_log.rb`, change:

```ruby
STATUSES = %w[pending processing completed failed].freeze
```

to:

```ruby
STATUSES = %w[pending processing completed failed paused cancelled].freeze
```

- [ ] **Step 3: Run model tests — the existing `"valid statuses are accepted"` test iterates `STATUSES`, so it now covers `paused` and `cancelled` automatically**

```bash
bin/rails test test/models/ai_scoring_log_test.rb
```

Expected: All green (same count — no new test file needed).

- [ ] **Step 4: Commit**

```bash
git add app/models/ai_scoring_log.rb
git commit -m "feat: add paused and cancelled statuses to AiScoringLog"
```

---

## Task 2: Update AiScoringJob — per-batch pause/cancel check

**Files:**
- Modify: `app/jobs/ai_scoring_job.rb`
- Test: `test/jobs/ai_scoring_job_test.rb`

- [ ] **Step 1: Write two failing tests — add inside the class, before the closing `end`, after all existing tests**

In `test/jobs/ai_scoring_job_test.rb`:

```ruby
# Test: job skips entirely when the log for this batch_id is already 'paused'
def test_job_skips_when_log_already_paused
  create_candidates_with_resumes(2)

  # Pre-create the log as 'paused' — simulates a previously-paused run with the same batch_id
  AiScoringLog.create!(
    batch_id:        @batch_id,
    opening_id:      @opening.id,
    requested_by_id: @user.id,
    status:          'paused',
    provider:        'chatgpt',
    model:           'fake-1'
  )

  AiScoringJob.perform_now(
    opening_id:      @opening.id,
    batch_id:        @batch_id,
    requested_by_id: @user.id,
    provider:        @fake_provider
  )

  assert_equal 0, @fake_provider.calls, "Provider should not be called when log is already paused"
  assert_equal 'paused', AiScoringLog.find_by(batch_id: @batch_id).status, "Log status must remain paused"
end

# Test: job stops at next batch boundary when log is set to 'paused' during processing
def test_job_stops_at_next_batch_boundary_when_paused_mid_run
  # Temporarily reduce CHUNK_SIZE to 1 so each candidate gets its own batch
  original_chunk = AiScoringJob::CHUNK_SIZE
  AiScoringJob.send(:remove_const, :CHUNK_SIZE)
  AiScoringJob.const_set(:CHUNK_SIZE, 1)

  create_candidates_with_resumes(2)
  target_batch_id = @batch_id

  # After the first candidate is scored (end of batch 1), set the log to 'paused'
  scored_count = 0
  orig_score   = AiScoringService.instance_method(:score)
  AiScoringService.define_method(:score) do |candidate:, opening:|
    scored_count += 1
    result = orig_score.bind(self).call(candidate: candidate, opening: opening)
    AiScoringLog.where(batch_id: target_batch_id).update_all(status: 'paused') if scored_count == 1
    result
  end

  AiScoringJob.perform_now(
    opening_id:      @opening.id,
    batch_id:        @batch_id,
    requested_by_id: @user.id,
    provider:        @fake_provider
  )

  assert_equal 1, @fake_provider.calls, "Only the first batch (1 candidate) should be scored"
  assert_equal 'paused', AiScoringLog.find_by(batch_id: @batch_id).status, "Log should remain paused"
  assert_equal 1, AiScore.where(opening_id: @opening.id).count, "Only 1 score should have been created"
ensure
  AiScoringJob.send(:remove_const, :CHUNK_SIZE)
  AiScoringJob.const_set(:CHUNK_SIZE, original_chunk)
  AiScoringService.define_method(:score, orig_score) if orig_score
end
```

- [ ] **Step 2: Run both new tests to confirm they fail**

```bash
bin/rails test test/jobs/ai_scoring_job_test.rb -n test_job_skips_when_log_already_paused
bin/rails test test/jobs/ai_scoring_job_test.rb -n test_job_stops_at_next_batch_boundary_when_paused_mid_run
```

Expected: Both fail — `paused` is not yet in the skip guard, and the batch-level check doesn't exist yet.

- [ ] **Step 3: Update `AiScoringJob#perform` — add `paused` and `cancelled` to the advisory-lock skip guard**

In `app/jobs/ai_scoring_job.rb`, find inside the `AiScoringLog.transaction` block:

```ruby
next if %w[processing completed failed].include?(log.status)
```

Change to:

```ruby
next if %w[processing completed failed paused cancelled].include?(log.status)
```

- [ ] **Step 4: Update `AiScoringJob#process_batch` — add per-batch break and conditional completion**

Replace the entire `process_batch` method with:

```ruby
def process_batch(log, provider_instance = nil)
  opening  = Opening.find(log.opening_id)
  provider = provider_instance || provider_for(log.provider)

  JdExtractionService.ensure_extracted(opening: opening, provider: provider)

  service = AiScoringService.new(provider: provider, log: log)
  scope   = candidates_scope(opening)
  log.update!(total_candidates: scope.count)

  scope.find_in_batches(batch_size: CHUNK_SIZE) do |batch|
    break if log.reload.status.in?(%w[paused cancelled])
    batch.each { |c| service.score(candidate: c, opening: opening) }
    ActiveRecord::Base.connection.clear_query_cache
    GC.compact
  end

  log.update!(status: 'completed', completed_at: Time.current) unless log.reload.status.in?(%w[paused cancelled])
ensure
  ActiveRecord::Base.connection.clear_query_cache
  GC.compact
end
```

- [ ] **Step 5: Run all job tests — both new tests should now pass, no regressions**

```bash
bin/rails test test/jobs/ai_scoring_job_test.rb
```

Expected: All green.

- [ ] **Step 6: Commit**

```bash
git add app/jobs/ai_scoring_job.rb test/jobs/ai_scoring_job_test.rb
git commit -m "feat: add per-batch pause/cancel check to AiScoringJob"
```

---

## Task 3: Update routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Update the ai_scores resource block**

In `config/routes.rb`, find (inside the `scope module: "opening"` block):

```ruby
resources :ai_scores, only: [:index, :create]
```

Replace with:

```ruby
resources :ai_scores, only: [:index, :create, :destroy] do
  collection do
    patch :pause
  end
end
```

- [ ] **Step 2: Verify routes are registered correctly**

```bash
bin/rails routes | grep ai_scores
```

Expected output (the four ai_scores routes):

```
  pause_opening_ai_scores PATCH  /openings/:opening_id/ai_scores/pause(.:format)  opening/ai_scores#pause
        opening_ai_scores GET    /openings/:opening_id/ai_scores(.:format)         opening/ai_scores#index
                          POST   /openings/:opening_id/ai_scores(.:format)         opening/ai_scores#create
                          DELETE /openings/:opening_id/ai_scores(.:format)         opening/ai_scores#destroy
```

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add pause (PATCH) and destroy (DELETE) routes for ai_scores"
```

---

## Task 4: Add `pause` action to Opening::AiScoresController

**Files:**
- Modify: `app/controllers/opening/ai_scores_controller.rb`
- Test: `test/controllers/opening/ai_scores_controller_test.rb`

- [ ] **Step 1: Write three failing tests for the pause action**

Add to `test/controllers/opening/ai_scores_controller_test.rb` (inside the class, after existing tests):

```ruby
# --- pause action ---

test "pause sets in-flight log to paused and redirects with notice" do
  login_user(@admin)

  log = @opening.ai_scoring_logs.create!(
    batch_id:        SecureRandom.uuid,
    requested_by_id: @admin.id,
    status:          'processing',
    provider:        'chatgpt',
    model:           'gpt-4o-mini'
  )

  patch pause_opening_ai_scores_path(@opening)

  assert_redirected_to opening_ai_scores_path(@opening)
  assert_match /paused/i, flash[:notice]
  assert_equal 'paused', log.reload.status
end

test "pause redirects with alert when no in-flight log exists" do
  login_user(@admin)

  # Ensure no pending/processing logs exist for this opening
  @opening.ai_scoring_logs.where(status: %w[pending processing]).delete_all

  patch pause_opening_ai_scores_path(@opening)

  assert_redirected_to opening_ai_scores_path(@opening)
  assert_match /No scoring run/i, flash[:alert]
end

test "pause is forbidden for non-admin users" do
  login_user(@user)

  @opening.ai_scoring_logs.create!(
    batch_id:        SecureRandom.uuid,
    requested_by_id: @admin.id,
    status:          'processing',
    provider:        'chatgpt',
    model:           'gpt-4o-mini'
  )

  patch pause_opening_ai_scores_path(@opening)

  assert_redirected_to root_path
end
```

- [ ] **Step 2: Run to confirm tests fail**

```bash
bin/rails test test/controllers/opening/ai_scores_controller_test.rb -n "/pause/"
```

Expected: All 3 fail (`AbstractController::ActionNotFound` or routing error — action doesn't exist yet).

- [ ] **Step 3: Add the `pause` action to the controller**

In `app/controllers/opening/ai_scores_controller.rb`, add after the `create` action and before `private`:

```ruby
# PATCH /openings/:opening_id/ai_scores/pause
def pause
  authorize @opening, :create?

  in_flight_log = @opening.ai_scoring_logs.find_by(status: %w[pending processing])

  unless in_flight_log
    redirect_to opening_ai_scores_path(@opening), alert: 'No scoring run is currently in progress.'
    return
  end

  in_flight_log.update!(status: 'paused')
  discard_queued_ai_scoring_jobs(@opening.id)

  redirect_to opening_ai_scores_path(@opening), notice: 'Scoring paused. Resume when ready.'
end
```

- [ ] **Step 4: Add `discard_queued_ai_scoring_jobs` to the private section**

In the `private` section of the controller, add after `estimate_cost_for_opening`:

```ruby
# Destroys SolidQueue jobs for AiScoringJob that are queued for this opening
# but have not yet been claimed by a worker. Running jobs (claimed executions)
# are handled by the DB-flag mechanism (they exit at the next batch boundary).
# Note: arguments is stored as a text column — cast to jsonb for JSON path querying.
def discard_queued_ai_scoring_jobs(opening_id)
  SolidQueue::Job
    .where(class_name: 'AiScoringJob', finished_at: nil)
    .where("(arguments::jsonb) -> 'arguments' -> 0 ->> 'opening_id' = ?", opening_id.to_s)
    .joins(:ready_execution)
    .destroy_all
end
```

- [ ] **Step 5: Run the three pause tests — all should be green**

```bash
bin/rails test test/controllers/opening/ai_scores_controller_test.rb -n "/pause/"
```

Expected: All 3 pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/opening/ai_scores_controller.rb test/controllers/opening/ai_scores_controller_test.rb
git commit -m "feat: add pause action to Opening::AiScoresController"
```

---

## Task 5: Add `destroy` action to Opening::AiScoresController

**Files:**
- Modify: `app/controllers/opening/ai_scores_controller.rb`
- Test: `test/controllers/opening/ai_scores_controller_test.rb`

- [ ] **Step 1: Write three failing tests for the destroy action**

Add to `test/controllers/opening/ai_scores_controller_test.rb`:

```ruby
# --- destroy action ---

test "destroy deletes all ai scores and logs for the opening and resets extraction fields" do
  login_user(@admin)

  # Fixtures provide scores and a log for web_opening; confirm they exist
  assert @opening.ai_scores.any?, "Fixture must have scores for web_opening"
  assert @opening.ai_scoring_logs.any?, "Fixture must have logs for web_opening"

  # Give the opening some extraction data to verify it gets cleared
  @opening.update!(must_have: [{ "skill" => "Ruby" }], good_to_have: [{ "skill" => "Rails" }], jd_requirements_hash: "abc123")

  delete opening_ai_scores_path(@opening)

  assert_redirected_to opening_ai_scores_path(@opening)
  assert_match /cleared/i, flash[:notice]
  assert_equal 0, AiScore.where(opening_id: @opening.id).count
  assert_equal 0, AiScoringLog.where(opening_id: @opening.id).count
  @opening.reload
  assert_equal [], @opening.must_have
  assert_equal [], @opening.good_to_have
  assert_nil @opening.jd_requirements_hash
end

test "destroy cancels in-flight log before wiping all logs" do
  login_user(@admin)

  in_flight = @opening.ai_scoring_logs.create!(
    batch_id:        SecureRandom.uuid,
    requested_by_id: @admin.id,
    status:          'processing',
    provider:        'chatgpt',
    model:           'gpt-4o-mini'
  )

  delete opening_ai_scores_path(@opening)

  assert_redirected_to opening_ai_scores_path(@opening)
  # All logs including the in-flight one are gone after clear
  assert_nil AiScoringLog.find_by(id: in_flight.id), "In-flight log must be deleted after clear"
  assert_equal 0, AiScoringLog.where(opening_id: @opening.id).count
end

test "destroy is forbidden for non-admin users" do
  login_user(@user)

  score_count_before = AiScore.where(opening_id: @opening.id).count

  delete opening_ai_scores_path(@opening)

  assert_redirected_to root_path
  assert_equal score_count_before, AiScore.where(opening_id: @opening.id).count, "Scores must not be deleted for non-admin"
end
```

- [ ] **Step 2: Run to confirm tests fail**

```bash
bin/rails test test/controllers/opening/ai_scores_controller_test.rb -n "/destroy/"
```

Expected: All 3 fail (`AbstractController::ActionNotFound` — action doesn't exist yet).

- [ ] **Step 3: Add the `destroy` action to the controller**

In `app/controllers/opening/ai_scores_controller.rb`, add after the `pause` action and before `private`:

```ruby
# DELETE /openings/:opening_id/ai_scores
def destroy
  authorize @opening, :create?

  # Signal any running job to stop at its next batch boundary before we delete
  @opening.ai_scoring_logs.where(status: %w[pending processing]).update_all(status: 'cancelled')

  # Remove queued-but-not-yet-running SolidQueue jobs for this opening
  discard_queued_ai_scoring_jobs(@opening.id)

  # Wipe all scores and all run history for this opening
  AiScore.where(opening_id: @opening.id).delete_all
  AiScoringLog.where(opening_id: @opening.id).delete_all

  # Reset JD extraction so the next run re-extracts requirements from scratch
  @opening.update!(must_have: [], good_to_have: [], jd_requirements_hash: nil)

  redirect_to opening_ai_scores_path(@opening), notice: 'All AI scores cleared successfully.'
end
```

- [ ] **Step 4: Run the three destroy tests — all should be green**

```bash
bin/rails test test/controllers/opening/ai_scores_controller_test.rb -n "/destroy/"
```

Expected: All 3 pass.

- [ ] **Step 5: Run the full controller test file to catch any regressions**

```bash
bin/rails test test/controllers/opening/ai_scores_controller_test.rb
```

Expected: All tests pass.

- [ ] **Step 6: Run the full test suite**

```bash
bin/rails test
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/opening/ai_scores_controller.rb test/controllers/opening/ai_scores_controller_test.rb
git commit -m "feat: add destroy (clear) action to Opening::AiScoresController"
```

---

## Task 6: Update the view — Pause button, Paused banner, Clear All Scores button

**Files:**
- Modify: `app/views/opening/ai_scores/index.html.erb`

The controller tests for index already assert `:success`, so any syntax error here will surface immediately.

- [ ] **Step 1: Add `paused` state variable at the very top of the file**

Find line 1:

```erb
<% in_progress = @latest_log&.status.in?(%w[pending processing]) %>
```

Replace with:

```erb
<% in_progress = @latest_log&.status.in?(%w[pending processing]) %>
<% paused      = @latest_log&.status == 'paused' %>
```

- [ ] **Step 2: Add a Pause button inside the in-progress blue banner**

Find inside the in-progress banner `<div class="flex items-center justify-between mb-3">` section:

```erb
<span class="text-xs text-blue-600 dark:text-blue-400">Auto-refreshing every 5s</span>
```

Replace with:

```erb
<div class="flex items-center gap-3">
  <span class="text-xs text-blue-600 dark:text-blue-400">Auto-refreshing every 5s</span>
  <%= button_to "Pause", pause_opening_ai_scores_path(@opening), method: :patch,
        class: "text-xs px-3 py-1.5 rounded-lg border border-blue-300 dark:border-blue-700 text-blue-700 dark:text-blue-300 bg-white dark:bg-gray-900 hover:bg-blue-50 dark:hover:bg-blue-950 transition-colors font-medium" %>
</div>
```

- [ ] **Step 3: Add the Paused banner — insert it before the `<!-- Warning banner -->` comment**

Find:

```erb
<!-- Warning banner -->
<% elsif @latest_log&.status == 'failed' %>
```

Insert the following block immediately before it:

```erb
<!-- Paused banner -->
<% elsif paused %>
  <% total  = @latest_log.total_candidates.to_i %>
  <% scored = @latest_log.successfully_scored.to_i %>
  <% failed = @latest_log.failed_count.to_i %>
  <% pct    = total > 0 ? ((scored + failed) * 100.0 / total).round : 0 %>
  <div class="mb-5 rounded-xl border border-yellow-200 bg-yellow-50 dark:bg-yellow-950 dark:border-yellow-800 p-4">
    <div class="flex items-center justify-between mb-3">
      <div class="flex items-center gap-2">
        <div class="h-2.5 w-2.5 rounded-full bg-yellow-500"></div>
        <span class="text-sm font-semibold text-yellow-800 dark:text-yellow-200">Scoring paused</span>
      </div>
      <span class="text-xs text-yellow-600 dark:text-yellow-400"><%= pct %>% complete before pause</span>
    </div>
    <div class="w-full bg-yellow-200 dark:bg-yellow-900 rounded-full h-2 mb-3">
      <div class="bg-yellow-500 h-2 rounded-full" style="width: <%= pct %>%"></div>
    </div>
    <div class="grid grid-cols-3 gap-3 text-center text-xs mb-3">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-2.5 border border-yellow-100 dark:border-yellow-900">
        <p class="text-base font-bold text-gray-800 dark:text-white"><%= total > 0 ? total : '…' %></p>
        <p class="text-gray-500 mt-0.5">Total</p>
      </div>
      <div class="bg-white dark:bg-gray-800 rounded-lg p-2.5 border border-yellow-100 dark:border-yellow-900">
        <p class="text-base font-bold text-green-600"><%= scored %></p>
        <p class="text-gray-500 mt-0.5">Scored</p>
      </div>
      <div class="bg-white dark:bg-gray-800 rounded-lg p-2.5 border border-yellow-100 dark:border-yellow-900">
        <p class="text-base font-bold text-red-500"><%= failed %></p>
        <p class="text-gray-500 mt-0.5">Skipped</p>
      </div>
    </div>
    <div class="flex items-center gap-2">
      <%= button_to "Resume Scoring", opening_ai_scores_path(@opening), method: :post,
            class: "btn-primary text-xs" %>
      <%= button_to "Clear All Scores", opening_ai_scores_path(@opening), method: :delete,
            data: { turbo_confirm: "This will delete all scores, run history, and reset JD requirements for this opening. Continue?" },
            class: "text-xs px-3 py-1.5 rounded-lg border border-red-300 dark:border-red-700 text-red-700 dark:text-red-300 bg-white dark:bg-gray-900 hover:bg-red-50 dark:hover:bg-red-950 transition-colors font-medium" %>
    </div>
  </div>

<!-- Warning banner -->
<% elsif @latest_log&.status == 'failed' %>
```

- [ ] **Step 4: Update the header card — add Clear All Scores button next to Generate Scores**

Find the header card's button block:

```erb
<% unless @latest_log&.status == 'failed' %>
  <%= button_to "Generate Scores", opening_ai_scores_path(@opening), method: :post, class: "btn-primary self-start" %>
<% end %>
<p class="text-xs text-gray-400 dark:text-gray-500">AI scores assist screening only — every decision still requires human review.</p>
```

Replace with:

```erb
<div class="flex items-center gap-2 mb-1">
  <% unless @latest_log&.status == 'failed' %>
    <%= button_to "Generate Scores", opening_ai_scores_path(@opening), method: :post,
          class: "btn-primary self-start" %>
  <% end %>
  <% if @latest_log.present? %>
    <%= button_to "Clear All Scores", opening_ai_scores_path(@opening), method: :delete,
          data: { turbo_confirm: "This will delete all scores, run history, and reset JD requirements for this opening. Continue?" },
          class: "text-xs px-3 py-1.5 rounded-lg border border-red-300 dark:border-red-700 text-red-700 dark:text-red-300 bg-white dark:bg-gray-900 hover:bg-red-50 dark:hover:bg-red-950 transition-colors font-medium self-start" %>
  <% end %>
</div>
<p class="text-xs text-gray-400 dark:text-gray-500">AI scores assist screening only — every decision still requires human review.</p>
```

- [ ] **Step 5: Update the right sidebar status badge to show `paused` in yellow**

Find in the right sidebar:

```erb
<span class="font-medium <%= @latest_log.status == 'completed' ? 'text-green-600' : @latest_log.status.in?(%w[pending processing]) ? 'text-blue-600' : 'text-yellow-600' %>">
  <%= @latest_log.status.humanize %>
</span>
```

Replace with:

```erb
<span class="font-medium <%=
  case @latest_log.status
  when 'completed' then 'text-green-600'
  when 'pending', 'processing' then 'text-blue-600'
  when 'paused' then 'text-yellow-500'
  else 'text-red-500'
  end
%>">
  <%= @latest_log.status.humanize %>
</span>
```

- [ ] **Step 6: Run the full controller test to confirm the view renders for all states**

```bash
bin/rails test test/controllers/opening/ai_scores_controller_test.rb
```

Expected: All tests pass.

- [ ] **Step 7: Run the complete test suite**

```bash
bin/rails test
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add app/views/opening/ai_scores/index.html.erb
git commit -m "feat: add Pause button, Paused banner, and Clear All Scores to AI scores UI"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|-----------------|------------|
| Pause: DB flag sets log to `paused` | Task 4 |
| Pause: discard queued SolidQueue jobs | Task 4 (`discard_queued_ai_scoring_jobs`) |
| Pause: running job exits at next batch boundary | Task 2 (job loop check) |
| Pause: memory freed via existing ensure block | Task 2 (ensure untouched — existing behaviour) |
| Pause: guard when no in-flight log | Task 4 (test + implementation) |
| Resume: existing `create` action (no code change) | ✅ No task needed — already works |
| Resume: UI button label changes to "Resume Scoring" when paused | Task 6 (Paused banner) |
| Clear: signals `cancelled` to running job | Task 5 |
| Clear: discards queued SolidQueue jobs | Task 5 (`discard_queued_ai_scoring_jobs`) |
| Clear: deletes all AiScores for opening | Task 5 |
| Clear: deletes all AiScoringLogs for opening | Task 5 |
| Clear: resets `must_have`, `good_to_have`, `jd_requirements_hash` | Task 5 |
| Clear: confirmation dialog | Task 6 (`data: { turbo_confirm: ... }`) |
| New statuses `paused` / `cancelled` valid in model | Task 1 |
| Advisory lock guard extended to skip `paused`/`cancelled` | Task 2 |
| Routes: `PATCH .../pause`, `DELETE ...` | Task 3 |
| Sidebar badge shows correct colour for `paused` | Task 6 |

**Placeholder scan:** None — all steps contain complete code.

**Type/name consistency:** `pause_opening_ai_scores_path`, `opening_ai_scores_path`, `@opening`, `@latest_log`, `discard_queued_ai_scoring_jobs` used identically across Tasks 4, 5, 6.
