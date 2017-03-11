class AddColumnToProduct < ActiveRecord::Migration
  def change
  	add_column :products, :is_inventory_product, :boolean, :default => false
  end
end
