class AddUpdatedOrdersImportColumnToImportItems < ActiveRecord::Migration[5.1]
  def change
    add_column :import_items, :updated_orders_import, :integer
  end
end
