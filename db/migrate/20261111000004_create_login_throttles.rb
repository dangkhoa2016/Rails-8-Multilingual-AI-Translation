class CreateLoginThrottles < ActiveRecord::Migration[8.1]
  def change
    create_table :login_throttles, id: false do |t|
      t.string :key, null: false, limit: 64
      t.integer :attempts, null: false, default: 0
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :login_throttles, :key, unique: true
    add_index :login_throttles, :expires_at
  end
end
