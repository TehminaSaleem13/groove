class AddIndexesToProductsAndRelatedTables < ActiveRecord::Migration[6.1]
  def change
    change_table :products, bulk: true do |t|
      t.index 'name(255)'
      t.index :updated_at
    end

    change_table :product_cats, bulk: true do |t|
      t.index :category
    end

    change_table :product_inventory_warehouses, bulk: true do |t|
      t.index :location_primary
      t.index :location_secondary
      t.index :location_tertiary
    end
  end
end
