class AddImportUpdatedSkuToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :import_updated_sku, :boolean, default: false
  end
end
