class AddLogglyGpxScanOrderToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :loggly_gpx_order_scan, :boolean, default: false
  end
end
