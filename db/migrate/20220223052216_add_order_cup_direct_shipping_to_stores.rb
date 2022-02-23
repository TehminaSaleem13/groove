class AddOrderCupDirectShippingToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :order_cup_direct_shipping, :boolean, default: false
  end
end
