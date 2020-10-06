class AddBarcodeAtImportToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
     add_column :general_settings, :create_barcode_at_import, :boolean, :default => false
  end
end
