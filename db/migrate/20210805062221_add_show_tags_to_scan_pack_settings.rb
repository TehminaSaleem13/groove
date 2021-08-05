class AddShowTagsToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :show_tags, :boolean, default: false
  end
end
