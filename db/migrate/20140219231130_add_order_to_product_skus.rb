class AddOrderToProductSkus < ActiveRecord::Migration[5.1]
  def change
    add_column :product_skus, :order, :integer, :default=>0
  end
end
