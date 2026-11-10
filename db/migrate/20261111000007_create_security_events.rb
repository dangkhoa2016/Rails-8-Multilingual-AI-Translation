class CreateSecurityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :security_events do |t|
      t.references :user, null: true, foreign_key: true
      t.string :event_type, null: false
      t.string :ip_hash, limit: 64, null: false
      t.timestamps
    end
    add_index :security_events, [:event_type, :created_at]
  end
end
