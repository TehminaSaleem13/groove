class AddPermitSharedBarcodesToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :permit_shared_barcodes, :boolean, default: false
  end
end
