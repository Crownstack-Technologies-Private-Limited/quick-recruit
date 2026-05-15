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

ActiveRecord::Schema[8.0].define(version: 2026_05_15_114951) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_scores", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.bigint "opening_id", null: false
    t.integer "score", null: false
    t.text "reasoning", null: false
    t.jsonb "matched_skills", default: {}, null: false
    t.jsonb "gaps", default: {}, null: false
    t.text "strengths"
    t.text "concerns"
    t.string "provider", null: false
    t.string "model", null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "output_tokens", default: 0, null: false
    t.decimal "cost", precision: 10, scale: 6, default: "0.0", null: false
    t.string "resume_version_hash"
    t.string "jd_version_hash"
    t.boolean "is_valid", default: true, null: false
    t.string "invalidation_reason"
    t.datetime "processed_at"
    t.datetime "expires_at"
    t.datetime "invalidated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id", "is_valid"], name: "index_ai_scores_on_candidate_id_and_is_valid"
    t.index ["candidate_id", "opening_id", "is_valid"], name: "index_ai_scores_one_valid_per_pair", unique: true, where: "(is_valid = true)"
    t.index ["candidate_id"], name: "index_ai_scores_on_candidate_id"
    t.index ["opening_id", "score"], name: "index_ai_scores_on_opening_and_score"
    t.index ["opening_id"], name: "index_ai_scores_on_opening_id"
    t.index ["processed_at"], name: "index_ai_scores_on_processed_at"
    t.index ["provider"], name: "index_ai_scores_on_provider"
    t.index ["resume_version_hash", "jd_version_hash"], name: "index_ai_scores_dedup"
  end

  create_table "ai_scoring_logs", force: :cascade do |t|
    t.bigint "opening_id", null: false
    t.bigint "requested_by_id", null: false
    t.string "batch_id", null: false
    t.integer "total_candidates", default: 0, null: false
    t.integer "successfully_scored", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.bigint "total_input_tokens", default: 0, null: false
    t.bigint "total_output_tokens", default: 0, null: false
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_ai_scoring_logs_on_batch_id", unique: true
    t.index ["opening_id", "created_at"], name: "index_logs_on_opening_and_date"
    t.index ["opening_id"], name: "index_ai_scoring_logs_on_opening_id"
    t.index ["requested_by_id"], name: "index_ai_scoring_logs_on_requested_by_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name"
    t.bigint "owner_id", null: false
    t.date "start_date"
    t.date "end_date"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_campaigns_on_owner_id"
  end

  create_table "campaigns_candidates", id: false, force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.bigint "campaign_id", null: false
  end

  create_table "candidates", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email"
    t.string "phone", null: false
    t.string "location"
    t.text "biography"
    t.string "linkedin"
    t.string "facebook"
    t.string "twitter"
    t.string "github"
    t.string "website"
    t.string "portfolio"
    t.string "current_company"
    t.string "current_title"
    t.string "current_ctc"
    t.string "expected_ctc"
    t.string "notice_period"
    t.decimal "experience", precision: 4, scale: 2
    t.integer "birth_year"
    t.string "highest_qualification"
    t.integer "bucket", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "role_id"
    t.bigint "source_id"
    t.bigint "opening_id"
    t.bigint "user_id", default: 1, null: false
    t.datetime "bucket_updated_on", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "zoho_id"
    t.string "zoho_job_id"
    t.bigint "owner_id", null: false
    t.integer "status", default: 0
    t.datetime "status_updated_on", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.date "joining_date"
    t.datetime "next_recycle_on", null: false
    t.string "resume_hash"
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
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "kind", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_emails_on_candidate_id"
    t.index ["user_id"], name: "index_emails_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action"
    t.integer "eventable_id"
    t.string "eventable_type"
    t.string "action_for_context"
    t.integer "trackable_id"
    t.string "trackable_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.string "title", null: false
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "nature", default: 0, null: false
    t.bigint "submitter_id", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["submitter_id"], name: "index_feedbacks_on_submitter_id"
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
    t.text "body"
    t.string "notable_type"
    t.bigint "notable_id"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "openings", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location"
    t.integer "opening_type", default: 0
    t.boolean "active", default: true
    t.bigint "role_id", default: 15, null: false
    t.integer "priority", default: 0
    t.bigint "owner_id", default: 1, null: false
    t.string "resume_screening_checklist"
    t.string "telephonic_screening_checklist"
    t.string "first_round_score"
    t.string "second_round_score"
    t.string "hr_round_score"
    t.index ["owner_id"], name: "index_openings_on_owner_id"
    t.index ["role_id"], name: "index_openings_on_role_id"
  end

  create_table "openings_users", force: :cascade do |t|
    t.bigint "opening_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["opening_id", "user_id"], name: "index_openings_users_on_opening_id_and_user_id", unique: true
    t.index ["opening_id"], name: "index_openings_users_on_opening_id"
    t.index ["user_id"], name: "index_openings_users_on_user_id"
  end

  create_table "recycles", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.boolean "recycled", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_recycles_on_candidate_id"
  end

  create_table "reports", force: :cascade do |t|
    t.string "title", null: false
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "nature", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "submitter_id", default: 1, null: false
    t.index ["submitter_id"], name: "index_reports_on_submitter_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0
    t.string "first_name"
    t.string "last_name"
    t.string "location"
    t.string "phone"
    t.text "biography"
    t.string "linkedin"
    t.string "facebook"
    t.string "twitter"
    t.string "github"
    t.string "website"
    t.string "portfolio"
    t.string "current_company"
    t.string "current_title"
    t.integer "experience"
    t.integer "birth_year"
    t.boolean "active", default: true
    t.datetime "inactive_at"
    t.string "zoho_id"
    t.string "booking_url"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
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
