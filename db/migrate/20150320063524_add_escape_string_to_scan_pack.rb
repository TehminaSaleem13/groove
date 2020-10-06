class AddEscapeStringToScanPack < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :escape_string, :string, :default=>' - '
    add_column :scan_pack_settings, :escape_string_enabled, :boolean, :default=> false
  end
end
