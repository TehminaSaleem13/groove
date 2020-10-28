class CreateStoreProductImports < ActiveRecord::Migration[5.1]
  def change
    create_table :store_product_imports do |t|
      t.string :status
      t.integer :success_imported, default: 0
      t.integer :success_updated, default: 0
      t.integer :total, default: 0
      t.integer :store_id
      t.string :current_sku
      t.integer :delayed_job_id

      t.timestamps
    end
  end
end
