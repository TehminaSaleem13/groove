class ChangeColumnsInAccessRestrictions < ActiveRecord::Migration
  def up
  	remove_column :access_restrictions, :tenant_id
  	change_column :access_restrictions, :num_users, :integer, :null => false, :default => '0'
  	change_column :access_restrictions, :num_shipments, :integer, :null => false, :default => '0'
  	change_column :access_restrictions, :num_import_sources, :integer, :null => false, :default => '0'
  	change_column :access_restrictions, :total_scanned_shipments, :integer, :null => false, :default => '0'
  end

  def down
  	add_column :access_restrictions, :tenant_id, :integer	
  end
end
