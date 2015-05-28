class ChangeScannedOnTypeInOrders < ActiveRecord::Migration
  def up
  	change_column :orders, :scanned_on, :datetime
  end

  def down
  	change_column :orders, :scanned_on, :date
  end
end
