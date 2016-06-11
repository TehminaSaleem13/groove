class AddIndexToOrdersForScanPack < ActiveRecord::Migration
  def change
    add_index :orders, [:non_hyphen_increment_id]
    add_index :orders, [:tracking_num]
  end
end
