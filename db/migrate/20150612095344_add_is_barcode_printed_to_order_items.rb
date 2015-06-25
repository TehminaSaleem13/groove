class AddIsBarcodePrintedToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :is_barcode_printed, :boolean, :default=>false
  end
end
