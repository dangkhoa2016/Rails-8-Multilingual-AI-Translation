class CreateUsersAndModels < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto"
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "admin"
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :translation_models do |t|
      t.string :model_key, null: false
      t.string :display_name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :translation_models, :model_key, unique: true

    create_table :inference_connections do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.string :adapter_key, null: false
      t.string :base_url, null: false
      t.string :auth_type, null: false, default: "bearer"
      t.text :api_token
      t.boolean :enabled, null: false, default: false
      t.datetime :last_checked_at
      t.string :last_check_status
      t.timestamps
    end

    create_table :model_deployments do |t|
      t.references :translation_model, null: false, foreign_key: true
      t.references :inference_connection, null: false, foreign_key: true
      t.string :remote_model_identifier, null: false
      t.boolean :active, null: false, default: false
      t.integer :config_version, null: false, default: 1
      t.timestamps
    end
    add_index :model_deployments, :translation_model_id, unique: true,
      where: "active = true", name: "only_one_active_deployment_per_model"

    create_table :inference_setting_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :translation_model, foreign_key: true
      t.references :inference_connection, foreign_key: true
      t.string :action, null: false
      t.jsonb :changes_summary, null: false, default: {}
      t.timestamps
    end
  end
end
