class AddColumnAllowShopifyInvPushToAccessRestrictions < ActiveRecord::Migration
  def change
    add_column :access_restrictions, :allow_shopify_inv_push, :boolean, :default => false
  end
end
