class AddImportTrackingInfoToShipstationRest < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :import_tracking_info, :boolean, default: false
  end
end
