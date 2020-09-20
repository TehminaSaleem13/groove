class AddBothPackingSlipOrShippingLabelToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :scan_by_packing_slip_or_shipping_label, :boolean, default: false
  end
end
