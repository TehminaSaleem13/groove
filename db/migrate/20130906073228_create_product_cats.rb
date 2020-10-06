class CreateProductCats < ActiveRecord::Migration[5.1]
  def change
    create_table :product_cats do |t|
      t.string :category
      t.references :product

      t.timestamps
    end
    # add_index :product_cats, :product_id
  end
end
