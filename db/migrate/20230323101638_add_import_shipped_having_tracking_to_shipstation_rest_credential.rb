class AddImportShippedHavingTrackingToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :import_shipped_having_tracking, :boolean, default:false
  end
end
