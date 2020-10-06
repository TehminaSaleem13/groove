class CreateProductImages < ActiveRecord::Migration[5.1]
  def change
    create_table :product_images do |t|
      t.references :product
      t.string :image

      t.timestamps
    end
    # add_index :product_images, :product_id
  end
end
