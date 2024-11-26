class AddOpenShopifyCreateShippingLabelToShopifyCredential < ActiveRecord::Migration[6.1]
  def change
    add_column :shopify_credentials, :open_shopify_create_shipping_label, :boolean, default: false
  end
end
