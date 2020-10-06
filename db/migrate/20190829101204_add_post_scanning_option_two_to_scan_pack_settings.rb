class AddPostScanningOptionTwoToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :post_scanning_option_second, :string, :default => 'None'
  end
end
