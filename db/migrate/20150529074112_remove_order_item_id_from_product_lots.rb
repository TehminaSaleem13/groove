class RemoveOrderItemIdFromProductLots < ActiveRecord::Migration
  def up
    remove_column :product_lots, :order_item_id
  end

  def down
    add_column :product_lots, :order_item_id, :integer
  end
end
