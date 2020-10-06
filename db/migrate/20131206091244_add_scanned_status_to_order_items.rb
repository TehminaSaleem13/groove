class AddScannedStatusToOrderItems < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :scanned_status, :string, :default=>'notscanned'
  end
end
