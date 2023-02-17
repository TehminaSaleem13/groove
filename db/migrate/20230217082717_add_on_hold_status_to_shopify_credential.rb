class AddOnHoldStatusToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :on_hold_status, :boolean, default:false
  end
end
