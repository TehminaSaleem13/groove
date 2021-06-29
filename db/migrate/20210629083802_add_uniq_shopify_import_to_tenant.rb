class AddUniqShopifyImportToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :uniq_shopify_import, :boolean, default: false
  end
end
