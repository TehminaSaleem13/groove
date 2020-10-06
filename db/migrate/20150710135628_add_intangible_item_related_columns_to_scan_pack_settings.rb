class AddIntangibleItemRelatedColumnsToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :intangible_setting_enabled, :boolean, :default=>false
    add_column :scan_pack_settings, :intangible_string, :string, :default=>''
  end
end
