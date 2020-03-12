class AddFieldsToShopifyCredential < ActiveRecord::Migration
  def change
    add_column :shopify_credentials, :product_last_import, :datetime
    add_column :shopify_credentials, :modified_barcode_handling, :string, default: 'add_to_existing'
    add_column :shopify_credentials, :generating_barcodes, :string, default: 'do_not_generate'
  end
end
