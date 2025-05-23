# frozen_string_literal: true

module ProductsService
  class AmazonImport < ProductsService::Base
    attr_accessor :product_hash

    def initialize(*args)
      @store_id, @product_sku, @product_id = args
      @store = Store.find(@store_id)
      @amazon_credentials = AmazonCredentials.where(store_id: @store_id)
      @credential = @amazon_credentials.first
      @product_hash = {}
    end

    def call
      return false if amazon_credentials_blank?

      do_get_matching_products
      do_find_update_product
    rescue StandardError => e
      puts e.inspect
    end

    private

    def amazon_credentials_blank?
      @amazon_credentials.blank?
    end

    def do_get_matching_products
      mws = Mws.connect(
        merchant: @credential.merchant_id,
        access: ENV['AMAZON_MWS_ACCESS_KEY_ID'],
        secret: ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
        marketplace_id: @credential.marketplace_id,
        MWS_auth_token: @credential.mws_auth_token
      )

      # send request to amazon mws get matching product API
      products_xml = mws.products.get_matching_products_for_id(
        marketplace_id: @credential.marketplace_id,
        id_type: 'SellerSKU', id_list: [@product_sku]
      )

      require 'active_support/core_ext/hash/conversions'

      @product_hash = Hash.from_xml(products_xml.to_s)
    end

    def do_find_update_product
      product = Product.find(@product_id)
      product_from_hash = product_hash['GetMatchingProductForIdResult']['Products']['Product']
      product_attributes = product_from_hash['AttributeSets']['ItemAttributes']

      product.name = product_attributes['Title']

      do_set_up_item_package_dimensions(product, product_attributes)

      product.store_product_id = product_from_hash['Identifiers']['MarketplaceASIN']['ASIN']

      do_import_images_and_category(product, product_attributes)

      add_inventory_warehouse(product)

      product.save
      product.update_product_status
    end

    def do_set_up_item_package_dimensions(product, product_attributes)
      product.weight = product_attributes['ItemDimensions'].try(:[], 'Weight').to_f * 16

      product.shipping_weight = product_attributes['PackageDimensions'].try(:[], 'Weight').to_f * 16
    end

    def add_inventory_warehouse(product)
      # add inventory warehouse
      inv_wh = ProductInventoryWarehouses.new
      inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
      product.product_inventory_warehousess << inv_wh
    end

    def do_import_images_and_category(product, product_attributes)
      if @credential.import_images
        image = ProductImage.new
        image.image = product_attributes['SmallImage']['URL']
        product.product_images << image
      end

      if @credential.import_products
        category = ProductCat.new
        category.category = product_attributes['ProductGroup']
        product.product_cats << category
      end
    end
  end
end
