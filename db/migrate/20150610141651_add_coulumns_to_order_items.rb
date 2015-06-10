class AddCoulumnsToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :is_barcode_printed, :boolean, :default=>false
    add_column :order_items, :is_incremental_item, :boolean, :default=>false
    add_column :order_items, :product_sku_id, :integer
    add_column :order_items, :product_barcode_id, :integer
  end
end
