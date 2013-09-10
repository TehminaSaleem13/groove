class CreateProductSkus < ActiveRecord::Migration
  def change
    create_table :product_skus do |t|
      t.string :sku
      t.string :purpose
      t.references :product

      t.timestamps
    end
    add_index :product_skus, :product_id
  end
end
