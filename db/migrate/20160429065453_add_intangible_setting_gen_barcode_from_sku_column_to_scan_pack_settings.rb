class AddIntangibleSettingGenBarcodeFromSkuColumnToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :intangible_setting_gen_barcode_from_sku, :boolean, :default => false
  end
end
