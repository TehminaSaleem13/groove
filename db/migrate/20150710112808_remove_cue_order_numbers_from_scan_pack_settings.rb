class RemoveCueOrderNumbersFromScanPackSettings < ActiveRecord::Migration
  def up
    remove_column :scan_pack_settings, :cue_orders_by
  end

  def down
    add_column :scan_pack_settings, :cue_orders_by, :string
  end
end
