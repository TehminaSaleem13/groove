class AddScannedStatusToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :scanned_status, :string, :default=>'notscanned'
  end
end
