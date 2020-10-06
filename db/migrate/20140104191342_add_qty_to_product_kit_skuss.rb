class AddQtyToProductKitSkuss < ActiveRecord::Migration[5.1]
  def change
    add_column :product_kit_skus, :qty, :integer, :default=>0
  end
end
