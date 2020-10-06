class AddClickedQtyToOrderItemKitProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :order_item_kit_products, :clicked_qty, :integer, default: 0
  end
end
