class AddColumnToProductImage < ActiveRecord::Migration
  def change
  	add_column :product_images, :placeholder, :boolean, :default => false 
  end
end
