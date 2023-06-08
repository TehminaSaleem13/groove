class AddLogglyShipworkImportToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :loggly_sw_imports, :boolean, default: false
  end
end
