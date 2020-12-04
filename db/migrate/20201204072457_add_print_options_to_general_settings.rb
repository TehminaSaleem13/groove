class AddPrintOptionsToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :print_post_scanning_barcodes, :boolean, default: false
    add_column :general_settings, :print_packing_slips, :boolean, default: false
    add_column :general_settings, :print_ss_shipping_labels, :boolean, default: false
  end
end
