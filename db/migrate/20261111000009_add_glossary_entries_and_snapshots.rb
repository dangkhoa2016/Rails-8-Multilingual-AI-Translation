class AddGlossaryEntriesAndSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :glossary_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source_language, null: false, limit: 64
      t.string :target_language, null: false, limit: 64
      t.text :source_term, null: false
      t.text :target_term, null: false
      t.text :notes
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :glossary_entries, [:user_id, :active, :source_language, :target_language],
      name: "index_glossary_by_owner_pair"

    add_column :translation_requests, :use_glossary, :boolean, null: false, default: false
    add_column :translation_requests, :glossary_snapshot, :text
  end
end
