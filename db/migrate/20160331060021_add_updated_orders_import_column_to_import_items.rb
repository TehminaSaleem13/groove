class AddUpdatedOrdersImportColumnToImportItems < ActiveRecord::Migration
  def change
    add_column :import_items, :updated_orders_import, :integer
  end
end
