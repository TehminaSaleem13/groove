class AddStoreIdToShipstationCredentials < ActiveRecord::Migration
  def up
    add_column :shipstation_credentials, :store_id, :integer
  end

  def down
  	remove_column :shipstation_credentials, :store_id
  end
end
