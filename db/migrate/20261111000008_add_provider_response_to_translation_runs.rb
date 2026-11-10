class AddProviderResponseToTranslationRuns < ActiveRecord::Migration[8.1]
  def change
    # Encrypted at the model layer. Old runs remain readable with a nil snapshot.
    add_column :translation_runs, :provider_response_json, :text
  end
end
