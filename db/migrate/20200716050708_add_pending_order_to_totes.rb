class AddPendingOrderToTotes < ActiveRecord::Migration
  def change
    add_column :totes, :pending_order_id, :integer, default: nil
  end
end
