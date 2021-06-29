class AddGdprShipstationToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :gdpr_shipstation, :boolean, default: false
  end
end
