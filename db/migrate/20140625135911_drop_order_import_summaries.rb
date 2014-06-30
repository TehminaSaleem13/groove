class DropOrderImportSummaries < ActiveRecord::Migration
  def up
  	drop_table :orders_import_summaries
  end

  def down
    create_table :orders_import_summaries do |t|
      t.integer :total_retrieved
      t.integer :success_imported
      t.integer :previous_imported
      t.boolean :status
      t.string :error_message
      t.references :store

      t.timestamps
    end
    add_index :orders_import_summaries, :store_id
  end
end
