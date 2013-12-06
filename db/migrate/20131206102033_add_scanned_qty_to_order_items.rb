class AddScannedQtyToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :scanned_qty, :integer, :default=>0
  end
end
