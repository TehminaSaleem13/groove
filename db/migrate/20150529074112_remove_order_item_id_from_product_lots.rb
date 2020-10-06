class RemoveOrderItemIdFromProductLots < ActiveRecord::Migration[5.1]
  def up
    remove_column :product_lots, :order_item_id
  end

  def down
    add_column :product_lots, :order_item_id, :integer
  end
end
