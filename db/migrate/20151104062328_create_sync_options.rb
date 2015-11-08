class CreateSyncOptions < ActiveRecord::Migration
  def change
    create_table :sync_options do |t|
      t.integer :product_id
      t.boolean :sync_with_bc, :default => false
      t.integer :bc_product_id

      t.timestamps
    end
  end
end
