class AddWorkerIdToImportItems < ActiveRecord::Migration[5.1]
  def change
    add_column :import_items, :importer_id, :string
  end
end
