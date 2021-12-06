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
      shopify_credential = store.shopify_credential
      return unless shopify_credential

      products = shopify_credential.fix_all_product_images ? Product.includes(:product_images).all : Product.includes(:product_images).where(store_id: params[:store_id])
      filter_product_ids = []
      products.each do |product|
        filter_product_ids << product.id if begin
                                               check_broken_image(product.product_images)
                                             rescue
                                               true
                                             end
      end

      # Getting Products List
      puts 'Getting Products List'
      shopify_products = begin
                           Groovepacker::ShopifyRuby::Client.new(shopify_credential).products('refresh_catalog', '')['products']
                         rescue
                           []
                         end

      puts 'Products List Fetched'
      # Add products with blank images & Products with corrupted images

      filter_products = Product.includes(:product_skus).where(id: filter_product_ids)

      # Skip products whose images are already fixed
      skip_product_ids = []

      shopify_products.each do |shopify_product|
        break if filter_products.blank?

        next if shopify_product['images'].blank?

        shopify_product['variants'].each do |s_variant|
          # Checking existing Product with that id or sku
          product = filter_products.where(store_product_id: s_variant['id']).first
          product = filter_products.where(product_skus: { sku: s_variant['sku'] }).first if product.blank? && s_variant['sku'].present?

          next unless product

          save_product_images(product, shopify_product['images'])

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

    def check_broken_image(images)
      broken_image = true
      images.each do |image|
        response = Net::HTTP.get_response(URI.parse(image.image))
        response = Net::HTTP.get_response(URI.parse(response.header['location'])) if response.code == '301'
        response = Net::HTTP.get_response(URI.parse(response.header['location'])) if response.code == '301'
        if response.code == '200' && !image.placeholder
          broken_image = false
          return broken_image
        end
      end
      broken_image
    end
  end
end
