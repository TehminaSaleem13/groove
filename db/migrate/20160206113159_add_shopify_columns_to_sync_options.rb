class AddShopifyColumnsToSyncOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :sync_options, :sync_with_shopify, :boolean, :default => false
    add_column :sync_options, :shopify_product_id, :integer
    add_column :sync_options, :shopify_product_sku, :string
  end
end
