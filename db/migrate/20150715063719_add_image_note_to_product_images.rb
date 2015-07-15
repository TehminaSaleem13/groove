class AddImageNoteToProductImages < ActiveRecord::Migration
  def change
    add_column :product_images, :image_note, :string
  end
end
