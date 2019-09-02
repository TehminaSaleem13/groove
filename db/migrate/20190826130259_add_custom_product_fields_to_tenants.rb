class AddCustomProductFieldsToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :custom_product_fields, :boolean, :default => false
  end
end
