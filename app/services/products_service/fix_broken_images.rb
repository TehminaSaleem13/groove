# frozen_string_literal: true

module ProductsService
  class FixBrokenImages < ProductsService::Base
    attr_accessor :tenant, :params

    def initialize(*args)
      @tenant = args[0]
      @params = args[1]
    end

    def call
      Apartment::Tenant.switch! tenant
      store = Store.find(params[:store_id])
      if store.store_type == 'Shopline'
        shop_credential = store.shopline_credential
      else
        shop_credential = store.shopify_credential
      end
      return unless shop_credential

      products = shop_credential.fix_all_product_images ? Product.includes(:product_images).all : Product.includes(:product_images).where(store_id: params[:store_id])
      filter_product_ids = []
      products.each do |product|
        filter_product_ids << product.id if product.broken_image?
      end

      # Getting Products List
      puts 'Getting Products List'
      shop_products = begin
                        if store.store_type == 'Shopline'
                          Groovepacker::ShoplineRuby::Client.new(shop_credential).products('refresh_catalog', '')['products']
                        else
                          Groovepacker::ShopifyRuby::Client.new(shop_credential).products('refresh_catalog', '')['products']
                        end
                      rescue StandardError
                        []
                      end

      puts 'Products List Fetched'
      # Add products with blank images & Products with corrupted images

      filter_products = Product.includes(:product_skus).where(id: filter_product_ids)

      # Skip products whose images are already fixed
      skip_product_ids = []

      shop_products.each do |shop_product|
        break if filter_products.blank?

        next if shop_product['images'].blank?

        shop_product['variants'].each do |s_variant|
          # Checking existing Product with that id or sku
          product = filter_products.where(store_product_id: s_variant['id']).first
          product = filter_products.where(product_skus: { sku: s_variant['sku'] }).first if product.blank? && s_variant['sku'].present?

          next unless product

          save_product_images(product, shop_product['images'])

          skip_product_ids << product.id
          filter_products = filter_products.where.not(id: skip_product_ids)
        end
      end
      CsvExportMailer.send_fix_shopify_product_images(tenant).deliver
    end

    private

    def save_product_images(product, images)
      product.product_images.destroy_all
      images.each do |image|
        product.product_images.create(image: image['src'])
      end
    end
  end
end
