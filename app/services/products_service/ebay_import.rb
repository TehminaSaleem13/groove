module ProductsService
  class EbayImport < ProductsService::ServiceInit
    def initialize(*args)
      @itemID, @sku, @ebay, @credential = args
      @product_id = 0
      @product_sku = ProductSku.where(:sku => @sku).first
    end

    def call
      @product_id = unless @product_sku.present?
        import_ebay_product
        @productdb.set_product_status
        @productdb.id
      else
        @product_sku.product_id
      end

      @product_id
    end

    private

    def import_ebay_product
      get_item
      create_new_db_product
      set_product_sku
      add_sku_to_db_product
      get_product_images
      get_product_categories
      add_inventory_warehouse
      @productdb.save
    end

    def get_item
      @item = ebay.getItem(:ItemID => @itemID).item
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
      #@item.productListingType.uPC
      @productdbsku.purpose = 'primary'
    end

    def item_sku
      @item.sKU || "not_available"
    end

    #publish the sku to the product record
    def add_sku_to_db_product
      @productdb.product_skus << @productdbsku
    end

    def get_product_images
      if can_import_images?
        @productimage = ProductImage.new
        @productimage.image = "http://i.ebayimg.com" +
          @item.pictureDetails.pictureURL.first.request_uri()
        add_product_images
      end
    end

    def can_import_images?
      credential.import_images && item_picture_url_valid?
    end

    def item_picture_url_valid?
      @item.pictureDetails.try(:pictureURL).present?
    end

    def add_product_images
      @productdb.product_images << @productimage
    end

    def get_product_categories
      if credential.import_products
        %w(primary secondary).each{|type| create_category(type)}
      end
    end

    def create_category(type)
      if @item.send("#{type}Category").present?
        @product_cat = ProductCat.new
        @product_cat.category = @item.send("#{type}Category").categoryName
        add_product_category
      end
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
