class CreateTranslationSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_requests, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true
      t.string :client_request_key, null: false
      t.text :source_text, null: false
      t.string :source_language, null: false
      t.string :target_language, null: false
      t.boolean :preserve_formatting, null: false, default: true
      t.string :status, null: false, default: "queued"
      t.references :preferred_model, foreign_key: { to_table: :translation_models }
      t.datetime :cost_acknowledged_at
      t.datetime :submitted_at
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :translation_requests, [:user_id, :client_request_key], unique: true

    create_table :translation_dispatches, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :translation_request, null: false, type: :uuid, foreign_key: true
      t.references :inference_connection, null: false, foreign_key: true
      t.string :provider_snapshot, null: false
      t.string :adapter_key_snapshot, null: false
      t.string :base_url_snapshot, null: false
      t.string :remote_model_identifier_snapshot, null: false
      t.string :payload_digest, null: false
      t.string :idempotency_key, null: false
      t.string :remote_job_id
      t.string :status, null: false, default: "pending"
      t.integer :poll_attempts, null: false, default: 0
      t.datetime :started_at
      t.datetime :last_polled_at
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :translation_dispatches, :idempotency_key, unique: true
    add_index :translation_dispatches, [:inference_connection_id, :remote_job_id],
      unique: true, where: "remote_job_id IS NOT NULL", name: "unique_remote_job_per_connection"

    create_table :translation_runs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :translation_request, null: false, type: :uuid, foreign_key: true
      t.references :translation_dispatch, type: :uuid, foreign_key: true
      t.references :translation_model, null: false, foreign_key: true
      t.references :model_deployment, foreign_key: true
      t.string :remote_run_id
      t.integer :attempt_no, null: false, default: 1
      t.string :status, null: false, default: "queued"
      t.text :translation_text
      t.string :error_code
      t.boolean :is_mock_result, null: false, default: false
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :translation_runs,
      [:translation_dispatch_id, :translation_model_id, :attempt_no],
      unique: true, name: "unique_local_dispatch_attempt"
    add_index :translation_runs, [:translation_dispatch_id, :remote_run_id],
      unique: true, where: "remote_run_id IS NOT NULL", name: "unique_remote_run_per_dispatch"
  end
end
