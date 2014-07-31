class CreateAccessRestrictions < ActiveRecord::Migration
  def up
    create_table :access_restrictions do |t|
    	t.integer :tenant_id
    	t.integer :num_users
    	t.integer :num_shipments
    	t.integer :num_import_sources
      t.timestamps
    end
  end
  def down
  	drop_table :access_restrictions
  end
end
