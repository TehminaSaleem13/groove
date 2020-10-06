class AddCaptionToProductImages < ActiveRecord::Migration[5.1]
  def change
    add_column :product_images, :caption, :string
  end
end
