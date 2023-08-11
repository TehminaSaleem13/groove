class CreateOriginStores < ActiveRecord::Migration[5.1]
  def change
    create_table :origin_stores do |t|
      t.integer :store_id
      t.integer :origin_store_id
      t.string :recent_order_details
      t.string :store_name, limit: 20
    end
    add_index :origin_stores, :store_id
    add_index :origin_stores, :origin_store_id
  end
end
