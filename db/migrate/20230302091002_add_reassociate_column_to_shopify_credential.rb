class AddReassociateColumnToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :re_associate_shopify_products, :string, default: 'associate_items'
  end
end
