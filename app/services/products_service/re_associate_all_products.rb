# frozen_string_literal: true

module ProductsService
  class ReAssociateAllProducts < ProductsService::Base
    attr_accessor :tenant, :params

    def initialize(*args)
      @tenant = args[0]
      @params = args[1]
    end

    def call
      Apartment::Tenant.switch! tenant
      store = Store.find(params[:store_id])
      shopify_credential = store.shopify_credential
      return unless shopify_credential

      update_re_associate_shopify_products(shopify_credential)
    end

    def fetch_shopify_products(shopify_credential)
      puts 'Getting Products List'
      shopify_products = begin
                          Groovepacker::ShopifyRuby::Client.new(shopify_credential).products('refresh_catalog', '')['products']
                        rescue StandardError
                          []
                        end
      shopify_products
    end

    def update_re_associate_shopify_products(shopify_credential)
      products = Product.all
      unconnected_items_ids = []
      products.each do |product|
        unconnected_items_ids << product.id if product.store_product_id.nil?
      end
      filtered_products = Product.where(id: unconnected_items_ids)

      if shopify_credential.re_associate_shopify_products == 're_associate_items'
        shopify_products = fetch_shopify_products(shopify_credential)
        filtered_products.each do |product|
          shopify_product = shopify_products.select { |p| product.product_skus.pluck(:sku).any? { |e| e.in? p['variants'].collect { |v| v['sku'] } }}.first
          next unless shopify_product
          filter_product_ids = []
          filter_product_ids << shopify_product['id']
          product.update(store_product_id: shopify_product['id'])
        end
      end
    end
  end
end
