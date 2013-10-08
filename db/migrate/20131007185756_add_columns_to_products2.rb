class AddColumnsToProducts2 < ActiveRecord::Migration
  def change
    add_column :products, :status, :string
    add_column :products, :spl_instructions_4_packer, :text
    add_column :products, :spl_instructions_4_confirmation, :text
    add_column :products, :alternate_location, :text
    add_column :products, :barcode, :text
    add_column :products, :is_skippable, :boolean
    add_column :products, :packing_placement, :integer
    add_column :products, :pack_time_adj, :integer
    add_column :products, :is_kit, :boolean
    add_column :products, :kit_skus, :text
    add_column :products, :kit_parsing, :string
    add_column :products, :inv_alert_wh1, :integer
    add_column :products, :inv_wh2_qty, :integer
    add_column :products, :inv_alert_wh2, :integer
    add_column :products, :inv_wh3_qty, :integer
    add_column :products, :inv_alert_wh3, :integer
    add_column :products, :inv_wh4_qty, :integer
    add_column :products, :inv_alert_wh4, :integer
    add_column :products, :inv_wh5_qty, :integer
    add_column :products, :inv_alert_wh5, :integer
    add_column :products, :inv_wh6_qty, :integer
    add_column :products, :inv_alert_wh6, :integer
    add_column :products, :inv_wh7_qty, :integer
    add_column :products, :inv_alert_wh7, :integer
  end
end
