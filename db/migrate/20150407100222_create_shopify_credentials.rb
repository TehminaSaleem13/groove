class CreateShopifyCredentials < ActiveRecord::Migration[5.1]
  def change
    create_table :shopify_credentials do |t|
      t.string :shop_name
      t.string :access_token
      t.integer :store_id

      t.timestamps
    end
  end
end
