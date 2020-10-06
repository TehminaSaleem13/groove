class AddColumnToProduct < ActiveRecord::Migration[5.1]
  def change
  	add_column :products, :is_inventory_product, :boolean, :default => false
  end
end
