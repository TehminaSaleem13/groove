class AddClickedQtyToOrderItemKitProducts < ActiveRecord::Migration
  def change
    add_column :order_item_kit_products, :clicked_qty, :integer, default: 0
  end
end
