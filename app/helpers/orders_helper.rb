module OrdersHelper
	require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'
  
	def import_magento_product(client, session, sku, store_id, import_images, import_products)
		begin
		response = client.call(:catalog_product_info, 
			message: {session: session, productId: sku})
		if response.success?
		  	@product  = response.body[:catalog_product_info_response][:info]
		  	

			#add product to the database
			@productdb = Product.new
			@productdb.name = @product[:name]
			@productdb.store_product_id = @product[:product_id]
			@productdb.product_type = @product[:type]
			@productdb.store_id = store_id
			@productdb.weight = @product[:weight].to_f * 16

			# Magento product api does not provide a barcode, so all
			# magento products should be marked with a status new as t
			#they cannot be scanned.
			@productdb.status = 'new'

			@productdbsku = ProductSku.new
			#add productdb sku
			if @product[:sku] != {:"@xsi:type"=>"xsd:string"}
				@productdbsku.sku = @product[:sku]
				@productdbsku.purpose = 'primary'

				#publish the sku to the product record
				@productdb.product_skus << @productdbsku
			end

			#get images and categories
			if !@product[:sku].nil? && import_images
				getimages = client.call(:catalog_product_attribute_media_list, message: {session: session,
					productId: sku})
				if getimages.success?
					@images = getimages.body[:catalog_product_attribute_media_list_response][:result][:item]
					if !@images.nil?
						if @images.kind_of?(Array)
							@images.each do |image|
								@productimage = ProductImage.new
								@productimage.image = image[:url]
								@productimage.caption = image[:label]
								@productdb.product_images << @productimage
							end
						else
							@productimage = ProductImage.new
							@productimage.image = @images[:url]
							@productimage.caption = @images[:label]
							@productdb.product_images << @productimage
						end
					end
				end
			end

			if !@product[:categories][:item].nil? &&
				@product[:categories][:item].kind_of?(Array)
				@product[:categories][:item].each do|category_id|
					begin
					get_categories = client.call(:catalog_product_info, message: {session: session,
						categoryId: category_id})
						if get_categories.success?
							@category = get_categories.body[:catalog_product_info_response][:info]
							@product_cat = ProductCat.new
							@product_cat.category = @category[:name]

							if !@product_cat.category.nil?
								@productdb.product_cats << @product_cat
							end
						end
					rescue
					end
				end
			end

			#add inventory warehouse
			inv_wh = ProductInventoryWarehouses.new
			inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
			@productdb.product_inventory_warehousess << inv_wh

			@productdb.save
			@productdb.set_product_status
		@productdb.id
		end
		rescue Exception => e
		end
	end

	def build_pack_item( name, product_type, images, sku, qty_remaining,
      scanned_qty, packing_placement,
      barcodes, product_id, order_item_id, child_items,instruction,confirmation,skippable, record_serial)

      unscanned_item = Hash.new
      unscanned_item["name"] = name
      unscanned_item["instruction"] = instruction
      unscanned_item["confirmation"] = confirmation
      unscanned_item["images"] = images
      unscanned_item["sku"] = sku
      unscanned_item["packing_placement"] = packing_placement
      unscanned_item["barcodes"] = barcodes
      unscanned_item["product_id"] = product_id
      unscanned_item["skippable"] = skippable
      unscanned_item["record_serial"] = record_serial
      unscanned_item["order_item_id"] = order_item_id
      unscanned_item["product_type"] = product_type
      unscanned_item["qty_remaining"] = qty_remaining
      unscanned_item["scanned_qty"] = scanned_qty

      if !child_items.nil?
        unscanned_item['child_items'] = child_items
      end

      return unscanned_item
    end

  def build_order_with_single_item_from_ebay(order, transaction, order_transaction)
    order.status = 'awaiting'
    order.store = @store
    order.increment_id = transaction.shippingDetails.sellingManagerSalesRecordNumber
    order.order_placed_time = transaction.createdDate

    if !transaction.buyer.nil? && !transaction.buyer.buyerInfo.nil? &&
      !transaction.buyer.buyerInfo.shippingAddress.nil?
      order.address_1  = transaction.buyer.buyerInfo.shippingAddress.street1
      order.city = transaction.buyer.buyerInfo.shippingAddress.cityName
      order.state = transaction.buyer.buyerInfo.shippingAddress.stateOrProvince
      order.country = transaction.buyer.buyerInfo.shippingAddress.country
      order.postcode = transaction.buyer.buyerInfo.shippingAddress.postalCode
      #split name separated by a space
      if !transaction.buyer.buyerInfo.shippingAddress.name.nil?
        split_name = transaction.buyer.buyerInfo.shippingAddress.name.split(' ')
        order.lastname = split_name.pop
        order.firstname = split_name.join(' ')
      end
    end

    #single item transaction does not have transaction array
    order_item = OrderItem.new
    order_item.price = transaction.transactionPrice
    order_item.qty = transaction.quantityPurchased
    order_item.row_total = transaction.amountPaid
    order_item.sku = order_transaction.transaction.item.sKU
    #create product if it does not exist already
    order_item.product_id =
    import_ebay_product(order_transaction.transaction.item.itemID,
    		order_transaction.transaction.item.sKU, @eBay, @credential)
    order.order_items << order_item

    order
  end

  def build_order_with_multiple_items_from_ebay(order, order_detail)
    order.status = 'awaiting'
    order.store = @store
    order.increment_id = order_detail.shippingDetails.sellingManagerSalesRecordNumber
    order.order_placed_time = order_detail.createdTime

    if !order_detail.shippingAddress.nil?
      order.address_1  = order_detail.shippingAddress.street1
      order.city = order_detail.shippingAddress.cityName
      order.state = order_detail.shippingAddress.stateOrProvince
      order.country = order_detail.shippingAddress.country
      order.postcode = order_detail.shippingAddress.postalCode
      #split name separated by a space
      if !order_detail.shippingAddress.name.nil?
        split_name = order_detail.shippingAddress.name.split(' ')
        order.lastname = split_name.pop
        order.firstname = split_name.join(' ')
      end
    end

    #multiple order items from transaction array
    order_detail.transactionArray.each do |transaction|
	    order_item = OrderItem.new
	    order_item.price = transaction.transactionPrice
	    order_item.qty = transaction.quantityPurchased
	    order_item.row_total = transaction.amountPaid
	    order_item.sku = transaction.item.sKU
	    #create product if it does not exist already
	    order_item.product_id =
	    import_ebay_product(transaction.item.itemID,
	    		transaction.item.sKU, @eBay, @credential)
	    order.order_items << order_item
	  end

   order
  end

  def generate_order_barcode(increment_id)
  	order_barcode = Barby::Code128B.new(increment_id)
    outputter = Barby::PngOutputter.new(order_barcode)
    outputter.margin = 0
    outputter.xdim = 2
    blob = outputter.to_png #Raw PNG data
    File.open("#{Rails.root}/public/images/#{increment_id}.png", 
      'w') do |f|
      f.write blob
    end
		increment_id
  end
end
