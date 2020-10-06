class RemoveUnusedColumnsFromProducts < ActiveRecord::Migration[5.1]
  def change
    remove_column :products, :inv_wh1
    remove_column :products, :alternate_location
    remove_column :products, :barcode
  end
end
