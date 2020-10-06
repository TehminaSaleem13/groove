class AddImportTypeToImportItems < ActiveRecord::Migration[5.1]
  def change
    add_column :import_items, :import_type, :string, default: 'regular'
  end
end
