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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_000009) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "glossary_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "source_language", limit: 64, null: false
    t.string "target_language", limit: 64, null: false
    t.text "source_term", null: false
    t.text "target_term", null: false
    t.text "notes"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "active", "source_language", "target_language"], name: "index_glossary_by_owner_pair"
    t.index ["user_id"], name: "index_glossary_entries_on_user_id"
  end

  create_table "inference_connections", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider", null: false
    t.string "adapter_key", null: false
    t.string "base_url", null: false
    t.string "auth_type", default: "bearer", null: false
    t.text "api_token"
    t.boolean "enabled", default: false, null: false
    t.datetime "last_checked_at"
    t.string "last_check_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "inference_setting_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "translation_model_id"
    t.bigint "inference_connection_id"
    t.string "action", null: false
    t.jsonb "changes_summary", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inference_connection_id"], name: "index_inference_setting_events_on_inference_connection_id"
    t.index ["translation_model_id"], name: "index_inference_setting_events_on_translation_model_id"
    t.index ["user_id"], name: "index_inference_setting_events_on_user_id"
  end

  create_table "login_throttles", id: false, force: :cascade do |t|
    t.string "key", limit: 64, null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_login_throttles_on_expires_at"
    t.index ["key"], name: "index_login_throttles_on_key", unique: true
  end

  create_table "model_deployments", force: :cascade do |t|
    t.bigint "translation_model_id", null: false
    t.bigint "inference_connection_id", null: false
    t.string "remote_model_identifier", null: false
    t.boolean "active", default: false, null: false
    t.integer "config_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inference_connection_id"], name: "index_model_deployments_on_inference_connection_id"
    t.index ["translation_model_id"], name: "index_model_deployments_on_translation_model_id"
    t.index ["translation_model_id"], name: "only_one_active_deployment_per_model", unique: true, where: "(active = true)"
  end

  create_table "security_events", force: :cascade do |t|
    t.bigint "user_id"
    t.string "event_type", null: false
    t.string "ip_hash", limit: 64, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type", "created_at"], name: "index_security_events_on_event_type_and_created_at"
    t.index ["user_id"], name: "index_security_events_on_user_id"
  end

  create_table "translation_dispatches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "translation_request_id", null: false
    t.bigint "inference_connection_id", null: false
    t.string "provider_snapshot", null: false
    t.string "adapter_key_snapshot", null: false
    t.string "base_url_snapshot", null: false
    t.string "remote_model_identifier_snapshot", null: false
    t.string "payload_digest", null: false
    t.string "idempotency_key", null: false
    t.string "remote_job_id"
    t.string "status", default: "pending", null: false
    t.integer "poll_attempts", default: 0, null: false
    t.datetime "started_at"
    t.datetime "last_polled_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_translation_dispatches_on_idempotency_key", unique: true
    t.index ["inference_connection_id", "remote_job_id"], name: "unique_remote_job_per_connection", unique: true, where: "(remote_job_id IS NOT NULL)"
    t.index ["inference_connection_id"], name: "index_translation_dispatches_on_inference_connection_id"
    t.index ["translation_request_id"], name: "index_translation_dispatches_on_translation_request_id"
  end

  create_table "translation_models", force: :cascade do |t|
    t.string "model_key", null: false
    t.string "display_name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_key"], name: "index_translation_models_on_model_key", unique: true
  end

  create_table "translation_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "client_request_key", null: false
    t.text "source_text", null: false
    t.string "source_language", null: false
    t.string "target_language", null: false
    t.boolean "preserve_formatting", default: true, null: false
    t.string "status", default: "queued", null: false
    t.bigint "preferred_model_id"
    t.datetime "cost_acknowledged_at"
    t.datetime "submitted_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ui_locale", default: "en", null: false
    t.boolean "use_glossary", default: false, null: false
    t.text "glossary_snapshot"
    t.index ["preferred_model_id"], name: "index_translation_requests_on_preferred_model_id"
    t.index ["user_id", "client_request_key"], name: "index_translation_requests_on_user_id_and_client_request_key", unique: true
    t.index ["user_id"], name: "index_translation_requests_on_user_id"
  end

  create_table "translation_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "translation_request_id", null: false
    t.uuid "translation_dispatch_id"
    t.bigint "translation_model_id", null: false
    t.bigint "model_deployment_id"
    t.string "remote_run_id"
    t.integer "attempt_no", default: 1, null: false
    t.string "status", default: "queued", null: false
    t.text "translation_text"
    t.string "error_code"
    t.boolean "is_mock_result", default: false, null: false
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "provider_response_json"
    t.index ["model_deployment_id"], name: "index_translation_runs_on_model_deployment_id"
    t.index ["translation_dispatch_id", "remote_run_id"], name: "unique_remote_run_per_dispatch", unique: true, where: "(remote_run_id IS NOT NULL)"
    t.index ["translation_dispatch_id", "translation_model_id", "attempt_no"], name: "unique_local_dispatch_attempt", unique: true
    t.index ["translation_dispatch_id"], name: "index_translation_runs_on_translation_dispatch_id"
    t.index ["translation_model_id"], name: "index_translation_runs_on_translation_model_id"
    t.index ["translation_request_id"], name: "index_translation_runs_on_translation_request_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.string "role", default: "admin", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "glossary_entries", "users"
  add_foreign_key "inference_setting_events", "inference_connections"
  add_foreign_key "inference_setting_events", "translation_models"
  add_foreign_key "inference_setting_events", "users"
  add_foreign_key "model_deployments", "inference_connections"
  add_foreign_key "model_deployments", "translation_models"
  add_foreign_key "security_events", "users"
  add_foreign_key "translation_dispatches", "inference_connections"
  add_foreign_key "translation_dispatches", "translation_requests"
  add_foreign_key "translation_requests", "translation_models", column: "preferred_model_id"
  add_foreign_key "translation_requests", "users"
  add_foreign_key "translation_runs", "model_deployments"
  add_foreign_key "translation_runs", "translation_dispatches"
  add_foreign_key "translation_runs", "translation_models"
  add_foreign_key "translation_runs", "translation_requests"
end
