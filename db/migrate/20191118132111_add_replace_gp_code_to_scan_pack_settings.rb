class AddReplaceGpCodeToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
  	add_column :scan_pack_settings, :replace_gp_code, :boolean, :default=>false
  end
end
