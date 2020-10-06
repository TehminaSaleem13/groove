class AddOrderIdToBox < ActiveRecord::Migration[5.1]
  def change
    add_column :boxes, :order_id, :integer
  end
end
