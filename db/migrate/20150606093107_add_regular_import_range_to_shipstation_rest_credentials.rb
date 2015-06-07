class AddRegularImportRangeToShipstationRestCredentials < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :regular_import_range, :integer, default: 3
  end
end
