class CreateCsvProductImports < ActiveRecord::Migration
  def change
    create_table :csv_product_imports do |t|
      t.string :status
      t.integer :success, :default => 0
      t.integer :total, :default => 0
      t.integer :store_id
      t.string :current_sku
      t.integer :delayed_job_id
      t.boolean :cancel, :default => false

      t.timestamps
    end
  end
end
