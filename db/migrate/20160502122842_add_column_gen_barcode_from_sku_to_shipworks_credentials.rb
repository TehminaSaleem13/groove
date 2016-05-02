class AddColumnGenBarcodeFromSkuToShipworksCredentials < ActiveRecord::Migration
  def change
    add_column :shipworks_credentials, :gen_barcode_from_sku, :boolean, :default => false
  end
end
