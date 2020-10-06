class AddColumnToProductImage < ActiveRecord::Migration[5.1]
  def change
  	add_column :product_images, :placeholder, :boolean, :default => false 
  end
end
