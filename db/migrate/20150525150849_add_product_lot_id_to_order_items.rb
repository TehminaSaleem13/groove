class AddProductLotIdToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :product_lot_id, :integer
  end
end
