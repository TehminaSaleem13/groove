class AddCueOrdersByToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :cue_orders_by, :string, :default=>'order_number'
  end
end
