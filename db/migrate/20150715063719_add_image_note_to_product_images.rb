class AddImageNoteToProductImages < ActiveRecord::Migration[5.1]
  def change
    add_column :product_images, :image_note, :string
  end
end
