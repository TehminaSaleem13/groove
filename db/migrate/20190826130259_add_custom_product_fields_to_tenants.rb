class AddCustomProductFieldsToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :custom_product_fields, :boolean, :default => false
  end
end
