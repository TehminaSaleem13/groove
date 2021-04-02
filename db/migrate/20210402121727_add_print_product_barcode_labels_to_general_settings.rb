class AddPrintProductBarcodeLabelsToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :print_product_barcode_labels, :boolean, default: false
  end
end
