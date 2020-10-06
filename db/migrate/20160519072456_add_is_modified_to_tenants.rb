class AddIsModifiedToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :is_modified, :boolean, :default => false
  end
end
