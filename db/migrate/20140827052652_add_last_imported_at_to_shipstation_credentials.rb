class AddLastImportedAtToShipstationCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_credentials, :last_imported_at, :datetime
  end
end
