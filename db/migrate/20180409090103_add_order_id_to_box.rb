class AddOrderIdToBox < ActiveRecord::Migration
  def change
    add_column :boxes, :order_id, :integer
  end
end
