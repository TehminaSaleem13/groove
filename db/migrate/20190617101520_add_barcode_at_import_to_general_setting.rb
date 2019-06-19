class AddBarcodeAtImportToGeneralSetting < ActiveRecord::Migration
  def change
     add_column :general_settings, :create_barcode_at_import, :boolean, :default => false
  end
end
