class AddLogglyColumnToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :loggly_shopify_imports, :boolean, default: false
    add_column :tenants, :loggly_se_imports, :boolean, default: false
  end
end
