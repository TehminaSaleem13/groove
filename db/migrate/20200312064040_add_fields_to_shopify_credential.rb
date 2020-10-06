class AddFieldsToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :product_last_import, :datetime unless column_exists? :shopify_credentials, :product_last_import
    add_column :shopify_credentials, :modified_barcode_handling, :string, default: 'add_to_existing' unless column_exists? :shopify_credentials, :modified_barcode_handling
    add_column :shopify_credentials, :generating_barcodes, :string, default: 'do_not_generate' unless column_exists? :shopify_credentials, :generating_barcodes
  end
end
