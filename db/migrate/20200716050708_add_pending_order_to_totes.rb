class AddPendingOrderToTotes < ActiveRecord::Migration[5.1]
  def change
    add_column :totes, :pending_order_id, :integer, default: nil
  end
end
