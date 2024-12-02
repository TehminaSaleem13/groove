class AddShopifyOrderFulfilledToShopifyCredential < ActiveRecord::Migration[6.1]
  def change
    add_column :shopify_credentials, :mark_shopify_order_fulfilled, :boolean, default: false
  end
end
