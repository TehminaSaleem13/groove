class AddOrderToProductSkus < ActiveRecord::Migration
  def change
    add_column :product_skus, :order, :integer, :default=>0
  end
end
