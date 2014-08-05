class AddTotalScannedShipmentsToAccessRestrictions < ActiveRecord::Migration
  def up
    add_column :access_restrictions, :total_scanned_shipments, :integer
  end
  def down
  	remove_column :access_restrictions, :total_scanned_shipments
  end
end
