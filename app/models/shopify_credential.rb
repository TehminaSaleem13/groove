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
    val += 'on_hold%2C' if on_hold_status?
    val
  end

  def self.add_tag_to_order(tenant, credential_id, store_order_id)
    Apartment::Tenant.switch! tenant
    tag = "GP SCANNED"
    client = Groovepacker::ShopifyRuby::Client.new(self.find(credential_id))
    client.add_gp_scanned_tag(store_order_id, tag)
  rescue StandardError => e
    puts e.backtrace.join(', ')
  end
end
