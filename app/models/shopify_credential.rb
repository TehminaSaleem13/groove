# frozen_string_literal: true

require 'shopify_api'
class ShopifyCredential < ApplicationRecord
  # attr_accessible :access_token, :shop_name, :store_id, :last_imported_at, :shopify_status, :shipped_status, :unshipped_status, :partial_status, :modified_barcode_handling, :generating_barcodes, :product_last_import, :import_inventory_qoh, :import_updated_sku, :updated_sku_handling, :permit_shared_barcodes

  attr_writer :permission_url

  belongs_to :store

  include AhoyEvent
  after_commit :log_events
  after_save :de_activate_webhooks # , :activate_webhooks

  serialize :temp_cookies, Hash

  def log_events
    object_changes = saved_changes.except(:last_imported_at, :updated_at, :created_at)
    return unless object_changes.present?

    track_changes(title: "#{self.class.name} Changed", tenant: Apartment::Tenant.current,
                  username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
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
    tag = 'GP SCANNED'
    client = Groovepacker::ShopifyRuby::Client.new(find(credential_id))
    client.add_gp_scanned_tag(store_order_id, tag)
  rescue StandardError => e
    puts e.backtrace.join(', ')
  end

  def activate_webhooks
    return unless saved_change_to_webhook_order_import?(from: false, to: true)

    Webhooks::Shopify::ShopifyWebhookService.new(self).activate_webhooks
  end

  def de_activate_webhooks
    return unless saved_change_to_webhook_order_import?(from: true, to: false)

    Webhooks::Shopify::ShopifyWebhookService.new(self).de_activate_webhooks
  end

  def push_inv_location
    @push_inv_location ||= locations.find { |loc| loc['id'] == push_inv_location_id } || locations.first
  end

  def pull_inv_location
    @pull_inv_location ||= locations.find { |loc| loc['id'] == pull_inv_location_id } || locations.first
  end

  def locations
    @locations ||= client.locations
  end

  def access_scopes
    @access_scopes ||= client.access_scopes
  end

  def client
    @client ||= Groovepacker::ShopifyRuby::Client.new(self)
  end
end
