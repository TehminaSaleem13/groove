class AddColumnToOrderItembox < ActiveRecord::Migration[5.1]
  def change
    add_column :order_item_boxes, :product_id, :integer
  end
end
