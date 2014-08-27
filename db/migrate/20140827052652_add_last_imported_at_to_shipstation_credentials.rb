class AddLastImportedAtToShipstationCredentials < ActiveRecord::Migration
  def change
    add_column :shipstation_credentials, :last_imported_at, :datetime
  end
end
