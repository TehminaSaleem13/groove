# frozen_string_literal: true

class ShopifyCredential < ActiveRecord::Base
  # attr_accessible :access_token, :shop_name, :store_id, :last_imported_at, :shopify_status, :shipped_status, :unshipped_status, :partial_status, :modified_barcode_handling, :generating_barcodes, :product_last_import, :import_inventory_qoh, :import_updated_sku, :updated_sku_handling, :permit_shared_barcodes

  attr_writer :permission_url

  belongs_to :store

  include AhoyEvent
  after_commit :log_events

  serialize :temp_cookies, Hash

  def log_events
    if saved_changes.present? && saved_changes.keys != ['updated_at'] && saved_changes.keys != %w[updated_at last_imported_at]
      track_changes(title: 'ShopifyCredential Changed', tenant: Apartment::Tenant.current,
                    username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
    end
  end

  def get_status
    val = ''
    val = 'shipped%2C' if shipped_status?
    val += 'unshipped%2C' if unshipped_status?
    val += 'partial%2C' if partial_status?
    val
  end
end
