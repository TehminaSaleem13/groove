class AddDefaultLocationIdToShopifyCredential < ActiveRecord::Migration[5.1]
  def up
    add_column :shopify_credentials, :default_location_id, :bigint
    set_deafult_location_id
  end

  def down
    remove_column :shopify_credentials, :default_location_id, :bigint
  end

  def set_deafult_location_id
    return unless defined?(ShopifyCredential)

    ShopifyCredential.all.each do |shopify_credential|
      first_location = shopify_credential.locations.first

      next unless first_location

      shopify_credential.update(default_location_id: first_location['id'])
    rescue StandardError => e
      Rollbar.error(e, e.message, Apartment::Tenant.current)
    end
  end
end
