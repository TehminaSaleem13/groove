class AddOrderToProductImages < ActiveRecord::Migration
  def change
    add_column :product_images, :order, :integer, :default=>0
  end
end
