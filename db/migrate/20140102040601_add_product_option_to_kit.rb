class AddProductOptionToKit < ActiveRecord::Migration
  def change
     add_column :product_kit_skus, :option_product_id, :integer
     remove_column :product_kit_skus, :sku
  end
end
