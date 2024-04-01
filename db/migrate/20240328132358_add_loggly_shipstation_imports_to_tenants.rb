class AddLogglyShipstationImportsToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :loggly_shipstation_imports, :boolean, default: false
  end
end
