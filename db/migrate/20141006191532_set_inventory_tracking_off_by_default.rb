class SetInventoryTrackingOffByDefault < ActiveRecord::Migration[5.1]
  def up
    change_column :general_settings, :inventory_tracking, :boolean, :default=>false
  end

  def down
    change_column :general_settings, :inventory_tracking, :boolean, :default=>true
  end
end
