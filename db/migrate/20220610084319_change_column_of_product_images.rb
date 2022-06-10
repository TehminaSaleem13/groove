class ChangeColumnOfProductImages < ActiveRecord::Migration[5.1]
  def up
  	change_column :product_images, :image, :text
  end

  def down
  	change_column :product_images, :image, :string
  end
end
