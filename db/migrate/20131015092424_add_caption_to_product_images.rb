class AddCaptionToProductImages < ActiveRecord::Migration
  def change
    add_column :product_images, :caption, :string
  end
end
