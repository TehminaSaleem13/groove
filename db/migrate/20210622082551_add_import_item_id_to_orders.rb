class AddImportItemIdToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :import_item_id, :string
  end
end
