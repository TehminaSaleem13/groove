class AddIndexToOrdersForScanPack < ActiveRecord::Migration[5.1]
  def change
    add_index :orders, [:non_hyphen_increment_id]
    add_index :orders, [:tracking_num]
  end
end
