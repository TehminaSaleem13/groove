class AddBoxToOrderItem < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :box_id, :integer
  end
end
