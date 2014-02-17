class AddPackingOrderToProductKitSkuss < ActiveRecord::Migration
  def change
    add_column :product_kit_skus, :packing_order, :integer, :default=>50
  end
end
