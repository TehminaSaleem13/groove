class AddColumnsToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :multi_box_shipments, :boolean, :default => false
    add_column :general_settings, :per_box_packing_slips, :string, :default => 'manually'
  end
end
