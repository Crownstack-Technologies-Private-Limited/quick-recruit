# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_20_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_scores", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.text "concerns"
    t.decimal "cost", precision: 10, scale: 6, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.jsonb "gaps", default: {}, null: false
    t.integer "input_tokens", default: 0, null: false
    t.datetime "invalidated_at"
    t.string "invalidation_reason"
    t.boolean "is_valid", default: true, null: false
    t.string "jd_version_hash"
    t.jsonb "matched_skills", default: {}, null: false
    t.string "model", null: false
    t.text "note"
    t.bigint "opening_id", null: false
    t.integer "output_tokens", default: 0, null: false
    t.datetime "processed_at"
    t.string "provider", null: false
    t.text "reasoning", null: false
    t.string "resume_version_hash"
    t.integer "score", null: false
    t.text "strengths"
    t.datetime "updated_at", null: false
    t.index ["candidate_id", "is_valid"], name: "index_ai_scores_on_candidate_id_and_is_valid"
    t.index ["candidate_id", "opening_id", "is_valid"], name: "index_ai_scores_one_valid_per_pair", unique: true, where: "(is_valid = true)"
    t.index ["candidate_id"], name: "index_ai_scores_on_candidate_id"
    t.index ["opening_id", "score"], name: "index_ai_scores_on_opening_score_valid", order: { score: :desc }, where: "(is_valid = true)"
    t.index ["opening_id"], name: "index_ai_scores_on_opening_id"
    t.index ["processed_at"], name: "index_ai_scores_on_processed_at"
    t.index ["provider"], name: "index_ai_scores_on_provider"
    t.index ["resume_version_hash", "jd_version_hash"], name: "index_ai_scores_dedup"
  end

  create_table "ai_scoring_logs", force: :cascade do |t|
    t.string "batch_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_details"
    t.integer "failed_count", default: 0, null: false
    t.string "model", null: false
    t.bigint "opening_id", null: false
    t.string "provider", null: false
    t.bigint "requested_by_id", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "successfully_scored", default: 0, null: false
    t.integer "total_candidates", default: 0, null: false
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.bigint "total_input_tokens", default: 0, null: false
    t.bigint "total_output_tokens", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_ai_scoring_logs_on_batch_id", unique: true
    t.index ["opening_id", "created_at"], name: "index_logs_on_opening_and_date"
    t.index ["opening_id"], name: "index_ai_scoring_logs_on_opening_id"
    t.index ["requested_by_id"], name: "index_ai_scoring_logs_on_requested_by_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "name"
    t.bigint "owner_id", null: false
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_campaigns_on_owner_id"
  end

  create_table "campaigns_candidates", id: false, force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "candidate_id", null: false
  end

  create_table "candidates", force: :cascade do |t|
    t.text "biography"
    t.integer "birth_year"
    t.integer "bucket", default: 0, null: false
    t.datetime "bucket_updated_on", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.string "current_company"
    t.string "current_ctc"
    t.string "current_title"
    t.string "email"
    t.string "expected_ctc"
    t.decimal "experience", precision: 4, scale: 2
    t.string "facebook"
    t.string "first_name", null: false
    t.string "github"
    t.string "highest_qualification"
    t.date "joining_date"
    t.string "last_name", null: false
    t.string "linkedin"
    t.string "location"
    t.datetime "next_recycle_on", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "notice_period"
    t.bigint "opening_id"
    t.bigint "owner_id", null: false
    t.string "phone", null: false
    t.string "portfolio"
    t.string "resume_hash"
    t.bigint "role_id"
    t.bigint "source_id"
    t.integer "status", default: 0
    t.datetime "status_updated_on", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "twitter"
    t.datetime "updated_at", null: false
    t.bigint "user_id", default: 1, null: false
    t.string "website"
    t.string "zoho_id"
    t.string "zoho_job_id"
    t.index ["bucket"], name: "index_candidates_on_bucket"
    t.index ["email"], name: "unique_emails", unique: true
    t.index ["opening_id"], name: "index_candidates_on_opening_id"
    t.index ["owner_id"], name: "index_candidates_on_owner_id"
    t.index ["resume_hash"], name: "index_candidates_on_resume_hash"
    t.index ["role_id"], name: "index_candidates_on_role_id"
    t.index ["source_id"], name: "index_candidates_on_source_id"
    t.index ["user_id"], name: "index_candidates_on_user_id"
  end

  create_table "emails", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["candidate_id"], name: "index_emails_on_candidate_id"
    t.index ["user_id"], name: "index_emails_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "action"
    t.string "action_for_context"
    t.datetime "created_at", null: false
    t.integer "eventable_id"
    t.string "eventable_type"
    t.integer "trackable_id"
    t.string "trackable_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "nature", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.bigint "submitter_id", default: 1, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["submitter_id"], name: "index_feedbacks_on_submitter_id"
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "notable_id"
    t.string "notable_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "opening_interviewers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "opening_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["opening_id", "user_id"], name: "index_opening_interviewers_on_opening_id_and_user_id", unique: true
    t.index ["opening_id"], name: "index_opening_interviewers_on_opening_id"
    t.index ["user_id"], name: "index_opening_interviewers_on_user_id"
  end

  create_table "openings", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "first_round_score"
    t.jsonb "good_to_have", default: []
    t.string "hr_round_score"
    t.string "jd_requirements_hash"
    t.string "location"
    t.integer "max_experience"
    t.integer "min_experience"
    t.jsonb "must_have", default: []
    t.integer "opening_type", default: 0
    t.bigint "owner_id", default: 1, null: false
    t.integer "priority", default: 0
    t.string "resume_screening_checklist"
    t.bigint "role_id", default: 15, null: false
    t.string "second_round_score"
    t.string "telephonic_screening_checklist"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_openings_on_owner_id"
    t.index ["role_id"], name: "index_openings_on_role_id"
  end

  create_table "openings_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "opening_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["opening_id", "user_id"], name: "index_openings_users_on_opening_id_and_user_id", unique: true
    t.index ["opening_id"], name: "index_openings_users_on_opening_id"
    t.index ["user_id"], name: "index_openings_users_on_user_id"
  end

  create_table "recycles", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.datetime "created_at", null: false
    t.boolean "recycled", default: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_recycles_on_candidate_id"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "nature", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.bigint "submitter_id", default: 1, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["submitter_id"], name: "index_reports_on_submitter_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true
    t.text "biography"
    t.integer "birth_year"
    t.string "booking_url"
    t.datetime "created_at", null: false
    t.string "current_company"
    t.string "current_title"
    t.string "email"
    t.integer "experience"
    t.string "facebook"
    t.string "first_name"
    t.string "github"
    t.datetime "inactive_at"
    t.string "last_name"
    t.string "linkedin"
    t.string "location"
    t.text "name"
    t.string "password_digest"
    t.string "phone"
    t.string "portfolio"
    t.integer "role", default: 0
    t.string "twitter"
    t.datetime "updated_at", null: false
    t.string "website"
    t.string "zoho_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_scores", "candidates"
  add_foreign_key "ai_scores", "openings"
  add_foreign_key "ai_scoring_logs", "openings"
  add_foreign_key "ai_scoring_logs", "users", column: "requested_by_id"
  add_foreign_key "campaigns", "users", column: "owner_id"
  add_foreign_key "candidates", "openings"
  add_foreign_key "candidates", "roles"
  add_foreign_key "candidates", "sources"
  add_foreign_key "candidates", "users"
  add_foreign_key "candidates", "users", column: "owner_id"
  add_foreign_key "emails", "candidates"
  add_foreign_key "emails", "users"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "feedbacks", "users", column: "submitter_id"
  add_foreign_key "notes", "users"
  add_foreign_key "opening_interviewers", "openings"
  add_foreign_key "opening_interviewers", "users"
  add_foreign_key "openings", "roles"
  add_foreign_key "openings", "users", column: "owner_id"
  add_foreign_key "openings_users", "openings"
  add_foreign_key "openings_users", "users"
  add_foreign_key "recycles", "candidates"
  add_foreign_key "reports", "users"
  add_foreign_key "reports", "users", column: "submitter_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
