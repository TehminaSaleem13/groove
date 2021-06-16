class RemoveIndexFromProductImages < ActiveRecord::Migration[5.1]
  def change
    remove_index :product_images, name: :index_product_images_on_image
  end
end
