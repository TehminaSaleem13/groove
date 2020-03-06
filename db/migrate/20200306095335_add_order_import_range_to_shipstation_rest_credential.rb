class AddOrderImportRangeToShipstationRestCredential < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :order_import_range_days, :integer, default: 30 
  end
end
