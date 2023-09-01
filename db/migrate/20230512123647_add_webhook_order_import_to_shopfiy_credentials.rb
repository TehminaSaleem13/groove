class AddWebhookOrderImportToShopfiyCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :webhook_order_import, :boolean, default: false
  end
end 
