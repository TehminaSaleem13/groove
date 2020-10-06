class CreateCsvMappings < ActiveRecord::Migration[5.1]
  def change
    create_table :csv_mappings do |t|
      t.integer :store_id
      t.text :order_map
      t.text :product_map

      t.timestamps
    end
  end
end
