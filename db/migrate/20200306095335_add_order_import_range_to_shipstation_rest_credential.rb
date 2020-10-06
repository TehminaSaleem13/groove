class AddOrderImportRangeToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :order_import_range_days, :integer, default: 30 unless column_exists? :shipstation_rest_credentials, :order_import_range_days
  end
end
