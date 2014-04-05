module OrdersHelper
	def import_magento_product(client, session, sku, store_id, import_images, import_products)
		begin
		response = client.call(:catalog_product_info, message: {session: session, productId: sku})
		if response.success?
		  	@product  = response.body[:catalog_product_info_response][:info]
			
			#add product to the database
			@productdb = Product.new
			@productdb.name = @product[:name]
			@productdb.store_product_id = @product[:product_id]
			@productdb.product_type = @product[:type]
			@productdb.store_id = store_id
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
      barcodes, product_id, order_item_id, child_items)

      unscanned_item = Hash.new
      
      unscanned_item["name"] = name
      unscanned_item["product_type"] = product_type
      unscanned_item["images"] = images
      unscanned_item["sku"] = sku
      unscanned_item["qty_remaining"] = qty_remaining
      unscanned_item["scanned_qty"] = scanned_qty
      unscanned_item["packing_placement"] = packing_placement
      unscanned_item["barcodes"] = barcodes
      unscanned_item["product_id"] = product_id
      unscanned_item["order_item_id"] = order_item_id

      if !child_items.nil?
        unscanned_item['child_items'] = child_items
      end

      return unscanned_item
    end
end
