class AddAddToAnyOrderToProducts < ActiveRecord::Migration
  def change
    add_column :products, :add_to_any_order, :boolean, :default => false
  end
end
