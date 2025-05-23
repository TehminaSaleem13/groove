# frozen_string_literal: true

module ProductsService
  class EbayImport < ProductsService::Base
    def initialize(*args)
      @itemID, @sku, @ebay, @credential = args
      @product_id = 0
      @store = Store.find(@credential.store_id)
      @product_sku = ProductSku.where(sku: @sku).first
    end

    def call
      @product_id = if @product_sku.present?
                      @product_sku.product_id
                    else
                      import_ebay_product
                      @productdb.set_product_status
                      @productdb.id
                    end

      @product_id
    end

    private

    def import_ebay_product
      @item = item_from_ebay
      create_new_db_product
      set_product_sku
      add_sku_to_db_product
      product_images
      product_categories
      add_inventory_warehouse
      @productdb.save
    end

    def item_from_ebay
      @ebay.getItem(ItemID: @itemID).item
    end

    def create_new_db_product
      @productdb = Product.new
      @productdb.name = @item.title
      @productdb.store_product_id = @item.itemID
      @productdb.product_type = 'not_used'
      @productdb.status = 'inactive'
      @productdb.store = @store
      @productdb.weight = product_weight
    end

    def product_weight
      weight_lbs = @item.shippingDetails.calculatedShippingRate.weightMajor
      weight_oz = @item.shippingDetails.calculatedShippingRate.weightMinor
      weight_lbs * 16 + weight_oz
    end

    def set_product_sku
      @productdbsku = ProductSku.new
      @productdbsku.sku = item_sku
      # @item.productListingType.uPC
      @productdbsku.purpose = 'primary'
    end

    def item_sku
      @item.sKU || 'not_available'
    end

    # publish the sku to the product record
    def add_sku_to_db_product
      @productdb.product_skus << @productdbsku
    end

    def product_images
      return unless can_import_images?

      @productimage = ProductImage.new
      @productimage.image = 'http://i.ebayimg.com' +
                            @item.pictureDetails.pictureURL.first.request_uri
      add_product_images
    end

    def can_import_images?
      @credential.import_images && item_picture_url_valid?
    end

    def item_picture_url_valid?
      @item.pictureDetails.try(:pictureURL).present?
    end

    def add_product_images
      @productdb.product_images << @productimage
    end

    def product_categories
      return unless @credential.import_products

      %w[primary secondary].each { |type| create_category(type) }
    end

    def create_category(type)
      return unless @item.send("#{type}Category").present?

      @product_cat = ProductCat.new
      @product_cat.category = @item.send("#{type}Category").categoryName
      add_product_category
    end

    def add_product_category
      @productdb.product_cats << @product_cat
    end

    def add_inventory_warehouse
      inv_wh = ProductInventoryWarehouses.new
      inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
      @productdb.product_inventory_warehousess << inv_wh
    end
  end
end
