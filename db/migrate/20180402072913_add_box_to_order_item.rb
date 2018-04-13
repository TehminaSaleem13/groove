class AddBoxToOrderItem < ActiveRecord::Migration
  def change
    add_column :order_items, :box_id, :integer
  end
end
