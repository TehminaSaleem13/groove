class AddOrderToProductImages < ActiveRecord::Migration[5.1]
  def change
    add_column :product_images, :order, :integer, :default=>0
  end
end
