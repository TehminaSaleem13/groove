class AddImportQohToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :import_inventory_qoh, :boolean, default: false
  end
end
