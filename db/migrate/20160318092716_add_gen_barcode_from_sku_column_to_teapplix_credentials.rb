class AddGenBarcodeFromSkuColumnToTeapplixCredentials < ActiveRecord::Migration
  def change
    add_column :teapplix_credentials, :gen_barcode_from_sku, :boolean, default: false
  end
end
