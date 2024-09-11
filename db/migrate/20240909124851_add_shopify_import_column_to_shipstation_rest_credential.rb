class AddShopifyImportColumnToShipstationRestCredential < ActiveRecord::Migration[6.1]
  def change
    add_column :shipstation_rest_credentials, :product_source_shopify_store_id, :integer
    add_column :shipstation_rest_credentials, :use_shopify_as_product_source_switch, :boolean, default: false
  end
end
