class AddSomeColumnsToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :camera_option, :string, default: 'photo'
    add_column :scan_pack_settings, :packing_option, :string, default: 'after_packing'
    add_column :scan_pack_settings, :resolution, :integer, default: 100
  end
end
