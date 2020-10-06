class ChangePriceTypeInOrderItems < ActiveRecord::Migration[5.1]
  def up
    change_column :order_items, :price, :decimal, :precision => 10, :scale => 2
  end

  def down
    change_column :order_items, :price, :decimal
  end
end
