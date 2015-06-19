class AddContainsUniqueOrderItemsToCsvMaps < ActiveRecord::Migration
  def change
    add_column :csv_maps, :contains_unique_order_items, :boolean, :default=>false
  end
end
