class AddRemoveSkippedToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :remove_skipped, :boolean, default: true
  end
end
