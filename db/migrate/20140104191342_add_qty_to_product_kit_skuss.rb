class AddQtyToProductKitSkuss < ActiveRecord::Migration
  def change
    add_column :product_kit_skus, :qty, :integer, :default=>0
  end
end
