class AddIndexToProductImages < ActiveRecord::Migration[5.1]
  def change
    add_index :product_images, :image
  end
end
