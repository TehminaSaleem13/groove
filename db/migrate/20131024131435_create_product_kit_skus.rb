class CreateProductKitSkus < ActiveRecord::Migration[5.1]
  def change
    create_table :product_kit_skus do |t|
      t.references :product
      t.string :sku

      t.timestamps
    end
    # add_index :product_kit_skus, :product_id
  end
end
