class CreateScanPackSettings < ActiveRecord::Migration
  def up
    create_table :scan_pack_settings do |t|
      t.boolean :enable_click_sku, :default => false
      t.boolean :ask_tracking_number, :default => true

      t.timestamps
    end
  end
  def down
    drop_table :scan_pack_settings
  end
end
