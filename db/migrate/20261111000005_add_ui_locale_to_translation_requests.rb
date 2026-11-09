class AddUiLocaleToTranslationRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :translation_requests, :ui_locale, :string, null: false, default: "en"
  end
end
