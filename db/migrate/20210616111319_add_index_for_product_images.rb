class AddIndexForProductImages < ActiveRecord::Migration[5.1]
  def change
    add_index :product_images, [:product_id, :image]
  end
end
