class CreateImportItems < ActiveRecord::Migration
  def up
  	create_table :import_items do |t|
      t.string :status
  		t.integer :store_id
      t.integer :success_imported, :default => 0
      t.integer :previous_imported, :default => 0
      
      t.timestamps
    end
  end

  def down
  	drop_table :import_items
  end
end
