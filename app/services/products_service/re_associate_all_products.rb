# frozen_string_literal: true

module ProductsService
  class ReAssociateAllProducts < ProductsService::Base
    attr_accessor :tenant, :params, :username, :shopify_credential, :result_data

    def initialize(**args)
      @tenant = args[:tenant]
      @params = args[:params]
      @username = args[:username]
      @result_data = {
        already_exists_barcodes: [],
        not_found_skus: []
      }
    end

    def call
      Apartment::Tenant.switch!(tenant)
      store = Store.find(params[:store_id])
      @shopify_credential = store.shopify_credential
      return unless shopify_credential

      update_re_associate_shopify_products
      send_re_associate_all_products_email
    end

    private

    def shopify_products
      return @shopify_products if @shopify_products

      @shopify_products ||= fetch_shopify_products
    end

    def update_re_associate_shopify_products
      products = Product.includes(:product_skus, :product_barcodes, :product_inventory_warehousess)
      filtered_products = filtered_products(products)

      filtered_products.each do |product|
        shopify_product = find_matching_shopify_product(product)
        handle_not_found_sku(product) unless shopify_product
        next unless shopify_product

        variant = find_matching_variant(product, shopify_product)
        create_barcode(product, variant['barcode']) if product.primary_barcode.nil?
        update_product(product, shopify_product)
      end
    end

    def fetch_shopify_products
      Groovepacker::ShopifyRuby::Client.new(shopify_credential).products('refresh_catalog', '')['products']
    rescue StandardError
      []
    end

    def filtered_products(products)
      if shopify_credential.re_associate_shopify_products == 're_associate_items'
        products
      else
        products.where(store_product_id: nil)
      end
    end

    def find_matching_shopify_product(product)
      shopify_products.find do |p|
        product.product_skus.pluck(:sku).any? { |e| e.in?(p['variants'].collect { |v| v['sku'] }) }
      end
    end

    def find_matching_variant(product, shopify_product)
      shopify_product['variants'].find { |v| v['sku'].in?(product.product_skus.pluck(:sku)) }
    end

    def create_barcode(product, barcode)
      product.product_barcodes.create(barcode: barcode, permit_shared_barcodes: true)
      add_barcode_activity(product, barcode)
      handle_already_exists_barcode(barcode)
    end

    def update_product(product, shopify_product)
      product.update(store_product_id: shopify_product['id'], store_id: shopify_credential.store_id)
      product.set_product_status
    end

    def handle_not_found_sku(product)
      result_data[:not_found_skus] << product.primary_sku if product.primary_sku.present?
    end

    def add_barcode_activity(product, barcode)
      user_name = username ? "#{username} - " : ''
      user_name += 'Re-associate all items with Shopify'
      product.add_product_activity( "The barcode #{barcode} was added to this item", user_name)
    end

    def handle_already_exists_barcode(barcode)
      return unless ProductBarcode.where(barcode: barcode).many?

      result_data[:already_exists_barcodes] << barcode
    end

    def send_re_associate_all_products_email
      CsvExportMailer.send_re_associate_all_products(tenant, result_data).deliver
    end
  end
end
