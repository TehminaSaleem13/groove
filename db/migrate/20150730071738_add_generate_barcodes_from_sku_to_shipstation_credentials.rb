class AddGenerateBarcodesFromSkuToShipstationCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :gen_barcode_from_sku, :boolean, default: false
  end
end
