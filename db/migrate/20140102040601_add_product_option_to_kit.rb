class AddProductOptionToKit < ActiveRecord::Migration[5.1]
  def change
     add_column :product_kit_skus, :option_product_id, :integer
     remove_column :product_kit_skus, :sku
  end
end
