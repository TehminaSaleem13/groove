class AddImportTypeToImportItems < ActiveRecord::Migration
  def change
    add_column :import_items, :import_type, :string, default: 'regular'
  end
end
