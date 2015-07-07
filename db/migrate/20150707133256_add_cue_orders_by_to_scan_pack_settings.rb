class AddCueOrdersByToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :cue_orders_by, :string, :default=>'order_number'
  end
end
