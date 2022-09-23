class AddTempCookiesToShopifyCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :temp_cookies, :longtext
  end
end
