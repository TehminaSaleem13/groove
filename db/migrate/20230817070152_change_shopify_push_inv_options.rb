class ChangeShopifyPushInvOptions < ActiveRecord::Migration[5.1]
  def up
    rename_column :shopify_credentials, :default_location_id, :push_inv_location_id
    add_column  :shopify_credentials, :pull_inv_location_id, :bigint
    add_column  :shopify_credentials, :pull_combined_qoh, :boolean, default: false
    set_pull_inv_location_id
  end

  def down
    rename_column :shopify_credentials, :push_inv_location_id, :default_location_id
    remove_column  :shopify_credentials, :pull_inv_location_id, :bigint
    remove_column  :shopify_credentials, :pull_combined_qoh, :boolean, default: false
  end

  def set_pull_inv_location_id
    return unless defined?(ShopifyCredential)

    ShopifyCredential.all.each do |shopify_credential|
      shopify_credential.update(pull_inv_location_id: shopify_credential.push_inv_location_id)
    rescue StandardError => e
      puts e
    end
  end
end
