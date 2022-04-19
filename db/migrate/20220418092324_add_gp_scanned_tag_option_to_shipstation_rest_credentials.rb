class AddGpScannedTagOptionToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :add_gpscanned_tag, :boolean, default: false
  end
end
