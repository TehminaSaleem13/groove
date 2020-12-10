class ShopifyCredential < ActiveRecord::Base
  # attr_accessible :access_token, :shop_name, :store_id, :last_imported_at, :shopify_status, :shipped_status, :unshipped_status, :partial_status, :modified_barcode_handling, :generating_barcodes, :product_last_import, :import_inventory_qoh, :import_updated_sku, :updated_sku_handling, :permit_shared_barcodes

  attr_writer :permission_url

  belongs_to :store

  include AhoyEvent
  after_commit :log_events

  def log_events
    track_changes(title: 'ShopifyCredential Changed', tenant: Apartment::Tenant.current,
                  username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes) if saved_changes.present? && saved_changes.keys != ['updated_at']
  end

  def get_status
  	val = ""
    val = "shipped%2C" if self.shipped_status?
    val = val +"unshipped%2C" if self.unshipped_status?
    val = val + "partial%2C" if self.partial_status?
    val
  end
end
