module ProductsHelper
	require 'mws-connect'
	#requires a product is created with appropriate seller sku
	def import_amazon_product_details(store_id, product_sku, product_id)
		begin
			@store = Store.find(store_id)
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
		end
  end

  def updatelist(product,var,value)
    if ["name","status","is_skippable"].include?(var)
      product[var] = value
      product.save
    elsif var ==  "sku"
      product_sku = product.product_skus.first
      if product_sku.nil?
        product_sku = ProductSku.new
        product_sku.product_id = product.id
      end
      product_sku.sku = value
      product_sku.save
    elsif var ==  "cat"
      product_cat = product.product_cats.first
      if product_cat.nil?
        product_cat = ProductCat.new
        product_cat.product_id = product.id
      end
      product_cat.category = value
      product_cat.save
    elsif var ==  "barcode"
      if ProductBarcode.where(:barcode => value).length == 0
        product_barcode = product.product_barcodes.first
        if product_barcode.nil?
          product_barcode = ProductBarcode.new
          product_barcode.product_id = product.id
        end
        product_barcode.barcode = value
        product_barcode.save
      end
    elsif ["location_primary" ,"location_secondary","location_name","qty"].include?(var)
      product_location = product.product_inventory_warehousess.first
      if product_location.nil?
        product_location = ProductInventoryWarehouses.new
        product_location.product_id = product.id
      end
        if var == "location_primary"
          product_location.location_primary = value
        elsif var == "location_secondary"
          product_location.location_secondary = value
        elsif var == "location_name"
          product_location.name = value
        elsif var == "qty"
          product_location.qty = value
        end
      product_location.save
    end
    product.update_product_status
  end
end
