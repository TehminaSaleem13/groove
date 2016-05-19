class AddIsModifiedToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :is_modified, :boolean, :default => false
  end
end
