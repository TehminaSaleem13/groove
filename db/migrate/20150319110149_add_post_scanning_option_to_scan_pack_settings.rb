class AddPostScanningOptionToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
  	add_column :scan_pack_settings, :post_scanning_option, :string, :default => 'None'
  end
end
