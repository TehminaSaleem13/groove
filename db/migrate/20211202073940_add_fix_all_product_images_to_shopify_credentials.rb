class AddFixAllProductImagesToShopifyCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :fix_all_product_images, :boolean, default: false
  end
end
