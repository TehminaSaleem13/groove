module ProductsHelper

  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

	require 'mws-connect'
	#requires a product is created with appropriate seller sku
	def import_amazon_product_details(store_id, product_sku, product_id)
		begin
			@store = Store.find(store_id)
      #puts "@store:"
      #puts @store.inspect
			@amazon_credentials = AmazonCredentials.where(:store_id => store_id)

			if @amazon_credentials.length > 0
				@credential = @amazon_credentials.first

				mws = Mws.connect(
					  merchant: @credential.merchant_id,
					  access: ENV['AMAZON_MWS_ACCESS_KEY_ID'],
					  secret: ENV['AMAZON_MWS_SECRET_ACCESS_KEY']
					)
				#send request to amazon mws get matching product API
				products_xml = mws.products.get_matching_products_for_id(:marketplace_id=>@credential.marketplace_id,
						:id_type=>'SellerSKU', :id_list=>[product_sku])

				require 'active_support/core_ext/hash/conversions'
				product_hash = Hash.from_xml(products_xml.to_s)

				product = Product.find(product_id)

				product.name = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['Title']

        if !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ItemDimensions'].nil? &&
          !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ItemDimensions']['Weight'].nil? 
          product.weight = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ItemDimensions']['Weight'].to_f * 16
        end

        if !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['PackageDimensions'].nil? &&
          !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['PackageDimensions']['Weight'].nil? 
          product.shipping_weight = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['PackageDimensions']['Weight'].to_f * 16
        end

				product.store_product_id = product_hash['GetMatchingProductForIdResult']['Products']['Product']['Identifiers']['MarketplaceASIN']['ASIN']

				if @credential.import_images
					image = ProductImage.new
					image.image = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['SmallImage']['URL']
					product.product_images << image
				end

				if @credential.import_products
					category = ProductCat.new
					category.category =  product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ProductGroup']
					product.product_cats << category
				end
        
        #add inventory warehouse
        inv_wh = ProductInventoryWarehouses.new
        inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
        product.product_inventory_warehousess << inv_wh

				product.save
				product.update_product_status
			end
		rescue Exception => e
      puts e.inspect
		end
  end

  def updatelist(product,var,value)
    begin
    if ['name','status','is_skippable','type_scan_enabled','click_scan_enabled'].include?(var)
      product[var] = value
      product.save
      if var == 'status'
        if value == 'inactive'
          product.update_product_status
        else
          product.update_due_to_inactive_product
        end
      end
    elsif var ==  'sku'
      product.primary_sku = value
    elsif var ==  'cat'
      product.primary_category = value
    elsif var ==  'barcode'
      product.primary_barcode = value
    elsif ['location_primary' ,'location_secondary', 'location_tertiary','location_name','qty'].include?(var)
      product_location = product.primary_warehouse
      if product_location.nil?
        product_location = ProductInventoryWarehouses.new
        product_location.product_id = product.id
        product_location.inventory_warehouse_id = current_user.inventory_warehouse_id
      end
        if var == 'location_primary'
          product_location.location_primary = value
        elsif var == 'location_secondary'
          product_location.location_secondary = value
        elsif var == 'location_tertiary'
          product_location.location_tertiary = value
        elsif var == 'location_name'
          product_location.name = value
        elsif var == 'qty'
          product_location.available_inv = value
          if GeneralSetting.first.inventory_auto_allocation == true
            product_location.save
            @order_items = product_location.product.order_items unless product_location.product.order_items.empty?
            @order_items.each do |order_item|
              order_item.order.update_inventory_level = false
              order_item.order.save
              if order_item.qty <= product_location.available_inv && order_item.inv_status != 'allocated'
                order_item.update_inventory_levels_for_packing(true)
              end
            end
          end
        end
      product_location.save
    end
    product.update_product_status
    @order_items.each do |order_item|
      order_item.order.update_inventory_level = true
      order_item.order.save
    end
    rescue Exception => e
      puts e.inspect
    end
  end

  #gets called from orders helper
  def import_ebay_product(itemID, sku, ebay, credential)
    product_id = 0
    if ProductSku.where(:sku=> sku).length == 0
      @item = ebay.getItem(:ItemID => itemID).item
      @productdb = Product.new
      @productdb.name = @item.title
      @productdb.store_product_id = @item.itemID
      @productdb.product_type = 'not_used'
      @productdb.status = 'inactive'
      @productdb.store = @store

      weight_lbs = @item.shippingDetails.calculatedShippingRate.weightMajor
      weight_oz = @item.shippingDetails.calculatedShippingRate.weightMinor
      @productdb.weight = weight_lbs * 16 + weight_oz

      #add productdb sku
      @productdbsku = ProductSku.new
      if  @item.sKU.nil?
        @productdbsku.sku = "not_available"
      else
        @productdbsku.sku = @item.sKU
      end
      #@item.productListingType.uPC
      @productdbsku.purpose = 'primary'

      #publish the sku to the product record
      @productdb.product_skus << @productdbsku

      if credential.import_images
        if !@item.pictureDetails.nil?
          if !@item.pictureDetails.pictureURL.nil? &&
            @item.pictureDetails.pictureURL.length > 0
            @productimage = ProductImage.new
            @productimage.image = "http://i.ebayimg.com" +
              @item.pictureDetails.pictureURL.first.request_uri()
            @productdb.product_images << @productimage

          end
        end
      end

      if credential.import_products
        if !@item.primaryCategory.nil?
          @product_cat = ProductCat.new
          @product_cat.category = @item.primaryCategory.categoryName
          @productdb.product_cats << @product_cat
        end

        if !@item.secondaryCategory.nil?
          @product_cat = ProductCat.new
          @product_cat.category = @item.secondaryCategory.categoryName
          @productdb.product_cats << @product_cat
        end
      end
      
      #add inventory warehouse
      inv_wh = ProductInventoryWarehouses.new
      inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
      @productdb.product_inventory_warehousess << inv_wh
      
      @productdb.save
      @productdb.set_product_status
      product_id = @productdb.id
    else
      product_id  = ProductSku.where(:sku=> sku).first.product_id
    end

    product_id
  end

  def generate_barcode(barcode_string)
    barcode = Barby::Code128B.new(barcode_string)
    outputter = Barby::PngOutputter.new(barcode)
    outputter.margin = 0
    blob = outputter.to_png #Raw PNG data
    image_name = Digest::MD5.hexdigest(barcode_string)
    File.open("#{Rails.root}/public/images/#{image_name}.png", 
      'w') do |f|
      f.write blob
    end
    image_name
  end  
end
