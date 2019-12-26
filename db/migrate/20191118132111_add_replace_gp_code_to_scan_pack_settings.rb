class AddReplaceGpCodeToScanPackSettings < ActiveRecord::Migration
  def change
  	add_column :scan_pack_settings, :replace_gp_code, :boolean, :default=>false
  end
end
