class AddImportQohToShopifyCredential < ActiveRecord::Migration
  def change
    add_column :shopify_credentials, :import_inventory_qoh, :boolean, default: false
  end
end
