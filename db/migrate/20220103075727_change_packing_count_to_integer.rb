class ChangePackingCountToInteger < ActiveRecord::Migration[5.1]
  def change
    ProductBarcode.where(packing_count: nil).update_all(packing_count: 1)
    change_column :product_barcodes, :packing_count, :integer, using: 'packing_count::integer', default: 1
  rescue
    ProductBarcode.all.each do |barcode|
      packing_count = barcode.packing_count.to_i.positive? ? barcode.packing_count.to_i : 1
      barcode.update_columns(packing_count: packing_count)
    end
    change_column :product_barcodes, :packing_count, :integer, using: 'packing_count::integer', default: 1
  end
end
