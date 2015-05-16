class AddShowNotesToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :show_customer_notes, :boolean, default: false
    add_column :scan_pack_settings, :show_internal_notes, :boolean, default: false
  end
end
