class AddSkuHandlingToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :updated_sku_handling, :string, default: 'add_to_existing'
  end
end
