class ProductsController < ApplicationController

	def importproducts
	@store = Store.find(params[:id])
	@result = Hash.new

	@result['status'] = true
	@result['messages'] = []
	@result['total_imported'] = 0
	@result['success_imported'] = 0
	@result['previous_imported'] = 0
	begin
	#import if magento products
	if @store.store_type == 'Magento' then
		@magento_credentials = MagentoCredentials.where(:store_id => @store.id)

		if @magento_credentials.length > 0
			client = Savon.client(wsdl: @magento_credentials.first.host+"/index.php/api/soap/index/wsdl/1")

			if !client.nil?

				response = client.call(:login,  message: { apiUser: @magento_credentials.first.username,
					apikey: @magento_credentials.first.api_key })

				if response.success?
					session =  response.body[:login_response][:login_return]
					response = client.call(:call, message: {session: session, method: 'product.list'})

					# fetching all products
					if response.success?
					  # listing found products
					  @products  = response.body[:call_response][:call_return][:item]
						@products .each do |product|
							product = product[:item]
							result_product = Hash.new

							product.each do |pkey|
								result_product[pkey[:key]] = pkey[:value]
							end

							@result['total_imported'] = @result['total_imported'] + 1

							if Product.where(:store_product_id=>result_product['product_id']).length  == 0
								#add product to the database
								@productdb = Product.new
								@productdb.name = result_product['name']
								@productdb.store_product_id = result_product['product_id']
								@productdb.product_type = result_product['type']
								@productdb.store = @store
								# Magento product api does not provide a barcode, so all
								# magento products should be marked with a status new as t
								#they cannot be scanned.
								@productdb.status = 'new'

								#add productdb sku
								@productdbsku = ProductSku.new
								@productdbsku.sku = result_product['sku']
								@productdbsku.purpose = 'primary'

								#publish the sku to the product record
								@productdb.product_skus << @productdbsku

								#get images and categories
								begin
								getimages = client.call(:call, message: {session: session,
									method: 'catalog_product_attribute_media.list',
									product: result_product['sku']})
								if getimages.success?
									@images = getimages.body[:call_response][:call_return][:item]
									if !@images.nil?
										if @images.length != 2
											@images.each do |image|
												image[:item].each do |itemhash|
													@productimage = ProductImage.new
													if itemhash[:key] == 'url'
														@productimage.image = itemhash[:value]
													end

													if itemhash[:key] == 'label'
														@productimage.caption = itemhash[:value]
													end

													if !@productimage.image.nil?
														@productdb.product_images << @productimage
													end
												end
											end
										end
									end
								end
								rescue

								end

								begin

								if !result_product['category_ids'][:item].nil? &&
									result_product['category_ids'][:item].kind_of?(Array)
									result_product['category_ids'][:item].each do|category_id|

										get_categories = client.call(:call, message: {session: session,
											method: 'catalog_category.info',
											categoryId: category_id})

										if get_categories.success?
											@categories = get_categories.body[:call_response][:call_return][:item]
											@categories.each do |category|
												if category[:key] == 'name'
													@product_cat = ProductCat.new
													@product_cat.category = category[:value]

													if !@product_cat.category.nil?
														@productdb.product_cats << @product_cat
													end
												end
											end
										end
									end
								end
								rescue
								end

								if ProductSku.where(:sku=>@productdbsku.sku).length == 0
									#save
									if @productdb.save
										@result['success_imported'] = @result['success_imported'] + 1
									end
								else
									@result['previous_imported'] = @result['previous_imported'] + 1
								end
							else
								@result['previous_imported'] = @result['previous_imported'] + 1
							end
						end
					else
						@result['status'] = false
						@result['messages'].push('Problem retrieving products list')
					end
				else
					@result['status'] = false
					@result['messages'].push('Problem connecting to Magento API. Authentication failed')
				end
			else
				@result['status'] = false
				@result['messages'].push('Problem connecting to Magento API. Check the hostname of the server')
			end
		else
			@result['status'] = false
			@result['messages'].push('No Store found!')
		end
	elsif @store.store_type == 'Ebay'
		#do ebay connect.
		@ebay_credentials = EbayCredentials.where(:store_id => @store.id)

		if @ebay_credentials.length > 0
			@credential = @ebay_credentials.first
			require 'eBayAPI'
			if ENV['EBAY_SANDBOX_MODE'] == 'YES'
				sandbox = true
			else
				sandbox = false
			end
			@eBay = EBay::API.new(@credential.productauth_token,
				        ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
        				ENV['EBAY_CERT_ID'], :sandbox=>sandbox)

			seller_list =@eBay.GetSellerList(:startTimeFrom=> (Date.today - 3.months).to_datetime,
				 :startTimeTo =>(Date.today + 1.day).to_datetime)

			@result['total_imported']  = seller_list.itemArray.length
			total_pages = (@result['total_imported'] / 10) +1
			page_num = 1
			begin
				seller_list =@eBay.GetSellerList(:startTimeFrom=> (Date.today - 3.months).to_datetime,
				 	 :startTimeTo =>(Date.today + 1.day).to_datetime, :detailLevel=>'ReturnAll',
					 :pagination=>{:entriesPerPage=> '10', :pageNumber=>page_num})
				page_num = page_num+1
				seller_list.itemArray.each do |item|
					#add product to the database
					if Product.where(:store_product_id=>item.itemID).length  == 0
						@productdb = Product.new
						@item = @eBay.getItem(:ItemID => item.itemID).item
						@productdb.name = @item.title
						@productdb.store_product_id = item.itemID
						@productdb.product_type = 'not_used'
						@productdb.status = 'Inactive'
						@productdb.store = @store

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


					if !@item.pictureDetails.nil?
						if !@item.pictureDetails.pictureURL.nil? &&
							@item.pictureDetails.pictureURL.length > 0
							@productimage = ProductImage.new
							@productimage.image = "http://i.ebayimg.com" +
								@item.pictureDetails.pictureURL.first.request_uri()
							@productdb.product_images << @productimage

						end

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

						if ProductSku.where(:sku=>@item.sKU).length == 0
							#save
							if @productdb.save
								@productdb.set_product_status
								@result['success_imported'] = @result['success_imported'] + 1
							end
						else
							@result['previous_imported'] = @result['previous_imported'] + 1
						end
					else
						@result['previous_imported'] = @result['previous_imported'] + 1
					end
				end
			end while(page_num <= total_pages)

		end
	elsif @store.store_type == 'Amazon'
		@amazon_credentials = AmazonCredentials.where(:store_id => @store.id)

		if @amazon_credentials.length > 0
			@credential = @amazon_credentials.first
			mws = MWS.new(:aws_access_key_id => ENV['AMAZON_MWS_ACCESS_KEY_ID'],
			  :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
			  :seller_id => @credential.merchant_id,
			  :marketplace_id => @credential.marketplace_id)
			#@result['aws-response'] = mws.reports.request_report :report_type=>'_GET_MERCHANT_LISTINGS_DATA_'
			#@result['aws-rewuest_status'] = mws.reports.get_report_request_list
			response = mws.reports.get_report :report_id=> params[:reportid]

			# _GET_MERCHANT_LISTINGS_DATA_
			# item-name
			# item-description
			# listing-id
			# seller-sku
			# price
			# quantity
			# open-date
			# image-url
			# item-is-marketplace
			# product-id-type
			# zshop-shipping-fee
			# item-note
			# item-condition
			# zshop-category1
			# zshop-browse-path
			# zshop-storefront-feature
			# asin1
			# asin2
			# asin3
			# will-ship-internationally
			# expedited-shipping
			# zshop-boldface
			# product-id
			# bid-for-featured-placement
			# add-delete
			# pending-quantity
			# fulfillment-channel

			require 'csv'
			csv = CSV.parse(response.body,:quote_char => "|")
			@result['total_imported']  = csv.length - 1
			csv.each_with_index do | row, index|
				if index > 0
					product_row = row.first.split(/\t/)
					if Product.where(:store_product_id=>product_row[2]).length  == 0
						@productdb = Product.new
						@productdb.name = product_row[0]
						@productdb.store_product_id = product_row[2]
						if @productdb.store_product_id.nil?
							@productdb.store_product_id = 'not_available'
						end

						@productdb.product_type = 'not_used'
						@productdb.status = 'new'
						@productdb.store = @store

						#add productdb sku
						@productdbsku = ProductSku.new
						@productdbsku.sku = product_row[3]
						@productdbsku.purpose = 'primary'

						#publish the sku to the product record
						@productdb.product_skus << @productdbsku

						@productimage = ProductImage.new
						@productimage.image = product_row[7]
						if !@productimage.image.nil? && @productimage.image != ""
							@productdb.product_images << @productimage
						end

						#save
						if ProductSku.where(:sku=>@productdbsku.sku).length == 0
							#save
							if @productdb.save
								@result['success_imported'] = @result['success_imported'] + 1
							end
						else
							@result['previous_imported'] = @result['previous_imported'] + 1
						end
					else
						@result['previous_imported'] = @result['previous_imported'] + 1
					end
			  	end
			end
		end
	end
	rescue Exception => e
		@result['status'] = false
		@result['messages'].push(e.message)
	end

    respond_to do |format|
      format.json { render json: @result}
    end

	end

	def requestamazonreport
		@amazon_credentials = AmazonCredentials.where(:store_id => params[:id])
		@result = Hash.new
		@result['status'] = false
		if @amazon_credentials.length > 0

			@credential = @amazon_credentials.first

			mws = MWS.new(:aws_access_key_id => ENV['AMAZON_MWS_ACCESS_KEY_ID'],
			  :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
		  	  :seller_id => @credential.merchant_id,
			  :marketplace_id => @credential.marketplace_id)

			response = mws.reports.request_report :report_type=>'_GET_MERCHANT_LISTINGS_DATA_'
			@credential.productreport_id = response.report_request_info.report_request_id
			@credential.productgenerated_report_id = nil

			if @credential.save
				@result['status'] = true
				@result['requestedreport_id'] = @credential.productreport_id
			end

		end

	    respond_to do |format|
	      format.json { render json: @result}
	    end
	end

	def checkamazonreportstatus
		@amazon_credentials = AmazonCredentials.where(:store_id => params[:id])
		@result = Hash.new
		@result['status'] = false
		report_found = false
		if @amazon_credentials.length > 0

			@credential = @amazon_credentials.first

			mws = MWS.new(:aws_access_key_id => ENV['AMAZON_MWS_ACCESS_KEY_ID'],
			  :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
			  :seller_id => @credential.merchant_id,
			  :marketplace_id => @credential.marketplace_id)

			@report_list = mws.reports.get_report_request_list
			@report_list.report_request_info.each do |report_request|
				if report_request.report_request_id == @credential.productreport_id
					report_found = true
					if report_request.report_processing_status == '_SUBMITTED_'
						@result['status'] = true
						@result['report_status'] = 'Report has been submitted successfully. '+
							'It is still being generated by the server.'
					elsif report_request.report_processing_status == '_DONE_'
						@result['report_status'] = 'Report is generated successfully.'

						@credential.productgenerated_report_id = report_request.generated_report_id
						@credential.productgenerated_report_date = report_request.completed_date
						if @credential.save
							@result['status'] = true
							@result['requestedreport_id'] = @credential.productreport_id
							@result['generated_report_id'] = report_request.generated_report_id
							@result['generated_report_date'] = report_request.completed_date
						end
					elsif report_request.report_processing_status == '_INPROGRESS_'
						@result['status'] = true
						@result['report_status'] = 'Report is in progress. It will be ready in few moments.'
					else
						@result['response'] = report_request
						#store generated report id
					end
				end
			end

			if !report_found
				@result['status'] = true
				@result['report_status'] = 'Report is not found. Please check back in few moments.'
			end
		end

	    respond_to do |format|
	      format.json { render json: @result}
	    end
	end
	# Get list of products based on limit and offset. It is by default sorted by updated_at field
	# If sort parameter is passed in then the corresponding sort filter will be used to sort the list
	# The expected parameters in params[:sort] are 'updated_at', name', 'sku', 'status', 'barcode', 'location_primary'
	# and quantity. The API supports to provide order of sorting namely ascending or descending. The parameter can be
	# passed in using params[:order] = 'ASC' or params[:order] ='DESC' [Note: Caps letters] By default, if no order is mentioned,
	# then the API considers order to be descending.The API also supports a product status filter.
	# The filter expects one of the following parameters in params[:filter] 'all', 'active', 'inactive', 'new'.
	# If no filter is passed, then the API will default to 'active'
	# if you would like to get Kits, specify params[:iskit] to 1. it will return product kits and the corresponding skus
	#
	def getproducts
		@result = Hash.new
		@result[:status] = true
		sort_key = 'updated_at'
		sort_order = 'DESC'
		status_filter = 'active'
		limit = 10
		offset = 0
		is_kit = 0
		supported_sort_keys = ['updated_at', 'name', 'sku',
								'status', 'barcode', 'location_primary', 'store' ]
		supported_order_keys = ['ASC', 'DESC' ] #Caps letters only
		supported_status_filters = ['all', 'active', 'inactive', 'new']
		supported_kit_params = ['0', '1']

		# Get passed in parameter variables if they are valid.
		limit = params[:limit] if !params[:limit].nil? && params[:limit].to_i > 0

		offset = params[:offset] if !params[:offset].nil? && params[:offset].to_i >= 0

		sort_key = params[:sort] if !params[:sort].nil? &&
			supported_sort_keys.include?(params[:sort])

		sort_order = params[:order] if !params[:order].nil? &&
			supported_order_keys.include?(params[:order])

		status_filter = params[:filter] if !params[:filter].nil? &&
			supported_status_filters.include?(params[:filter])

		is_kit = params[:iskit] if !params[:iskit].nil?  &&
			supported_kit_params.include?(params[:iskit])

		#hack to bypass for now and enable client development
		# sort_key = 'name' if sort_key == 'sku'

		#todo status filters to be implemented
		if sort_key == 'sku'
			if status_filter == 'all'
				@products = Product.find_by_sql('SELECT products.* FROM products, product_skus WHERE '+
				'products.id = product_skus.product_id  AND products.is_kit='+is_kit+
				' ORDER BY product_skus.sku '+sort_order+' LIMIT '+limit+' OFFSET '+offset)
			else
				@products = Product.find_by_sql('SELECT products.* FROM products, product_skus WHERE '+
				'products.id = product_skus.product_id AND products.is_kit='+is_kit+
				' AND products.status=\''+status_filter.capitalize+
				'\' ORDER BY product_skus.sku '+sort_order+' LIMIT '+limit+' OFFSET '+offset)
			end
		elsif sort_key == 'store'
			if status_filter == 'all'
				@products = Product.find_by_sql('SELECT products.* FROM products, stores WHERE '+
				'products.store_id = stores.id  AND products.is_kit='+is_kit+
				' ORDER BY stores.name '+sort_order+' LIMIT '+limit+' OFFSET '+offset)
			else
				@products = Product.find_by_sql('SELECT products.* FROM products, stores WHERE '+
				'products.store_id = stores.id AND products.is_kit='+is_kit+
				' AND products.status=\''+status_filter.capitalize+
				'\' ORDER BY stores.name '+sort_order+' LIMIT '+limit+' OFFSET '+offset)
			end
		elsif sort_key == 'location_primary'
			if status_filter == 'all'
				@products = Product.find_by_sql('SELECT products.* FROM products, product_inventory_warehouses WHERE '+
				'products.id = product_inventory_warehouses.product_id  AND products.is_kit='+is_kit+
				' ORDER BY product_inventory_warehouses.location_primary '+sort_order+' LIMIT '+limit+' OFFSET '+offset)
			else
				@products = Product.find_by_sql('SELECT products.* FROM products, product_inventory_warehouses WHERE '+
				'products.id = product_inventory_warehouses.product_id AND products.is_kit='+is_kit+
				' AND products.status=\''+status_filter.capitalize+
				'\' ORDER BY product_inventory_warehouses.location_primary '+sort_order+' LIMIT '+limit+' OFFSET '+offset)
			end
		else
			if status_filter == 'all'
				@products = Product.limit(limit).offset(offset).order(sort_key+" "+sort_order).
				where(:is_kit=> is_kit)
			else
				@products = Product.limit(limit).offset(offset).order(sort_key+" "+sort_order).
				where(:status=>status_filter.capitalize).where(:is_kit=>is_kit)
			end
		end

		if @products.length==0
			if status_filter == 'all'
				@products = Product.limit(limit).offset(offset).
				where(:is_kit=> is_kit)
			else
				@products = Product.limit(limit).offset(offset).
				where(:status=>status_filter.capitalize).where(:is_kit=>is_kit)
			end
		end

		@products_result = []

		@products.each do |product|
		@product_hash = Hash.new
		@product_hash['id'] = product.id
		@product_hash['name'] = product.name
		@product_hash['status'] = product.status
    @product_hash['location'] = ""
    @product_hash['location_secondary'] = ""
    @product_hash['location_name'] = ""
    @product_hash['qty'] = ""
    @product_hash['barcode'] = ""
    @product_hash['sku'] = ""
    @product_hash['cat'] = ""

    @product_location = product.product_inventory_warehousess.first
    unless @product_location.nil?
      @product_hash['location'] = @product_location.location_primary
      @product_hash['location_secondary'] = @product_location.location_secondary
      @product_hash['location_name'] = @product_location.name
      @product_hash["qty"] = @product_location.qty
    end

    @product_barcode = product.product_barcodes.first
    unless @product_barcode.nil?
      @product_hash['barcode'] = @product_barcode.barcode
    end

    @product_sku = product.product_skus.first
    unless @product_sku.nil?
      @product_hash['sku'] = @product_sku.sku
    end

    @product_cat = product.product_cats.first
    unless @product_cat.nil?
      @product_hash['cat'] = @product_cat.category
    end
    unless product.store.nil?
      @product_hash['store_type'] = product.store.store_type
    end

		@product_kit_skus = ProductKitSkus.where(:product_id=>product.id)
		if @product_kit_skus.length > 0
			@product_hash['productkitskus'] = []
			@product_kit_skus.each do |kitsku|
				@product_hash['productkitskus'].push(kitsku.sku)
			end
		end

		@products_result.push(@product_hash)
		end

		@result['products'] = @products_result

		respond_to do |format|
      		format.json { render json: @result}
    	end
	end

  def duplicateproduct

    @result = Hash.new
    @result['status'] = true
    if params[:select_all]
      #todo: implement search and filter by status
      @products = params[:productArray]
    else
      @products = params[:productArray]
    end
    unless @products.nil?
      @products.each do|product|

        @product = Product.find(product["id"])

        @newproduct = @product.dup
        index = 0
        @newproduct.name = @product.name+"(duplicate"+index.to_s+")"
        @productslist = Product.where(:name=>@newproduct.name)
        begin
          index = index + 1
          #todo: duplicate sku, images, categories associated with product too.
          @newproduct.name = @product.name+"(duplicate"+index.to_s+")"
          @productslist = Product.where(:name=>@newproduct.name)
        end while(!@productslist.nil? && @productslist.length > 0)

        if !@newproduct.save(:validate => false)
          @result['status'] = false
          @result['messages'] = @newproduct.errors.full_messages
        end
      end
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deleteproduct
    @result = Hash.new
    @result['status'] = true
    if params[:select_all]
      #todo: implement search and filter by status
      @products = params[:productArray]
    else
      @products = params[:productArray]
    end
    unless @products.nil?
      @products.each do|product|
        @product = Product.find(product["id"])
        if @product.destroy
          @result['status'] &= true
        else
          @result['status'] &= false
          @result['messages'] = @product.errors.full_messages
        end
      end
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end
  # For search pass in parameter params[:search] and a params[:limit] and params[:offset].
  # If limit and offset are not passed, then it will be default to 10 and 0
  def search
  	@result = Hash.new
  	@result['status'] = true
	limit = 10
	offset = 0
	# Get passed in parameter variables if they are valid.
	limit = params[:limit] if !params[:limit].nil? && params[:limit].to_i > 0

	offset = params[:offset] if !params[:offset].nil? && params[:offset].to_i >= 0

	if !params[:search].nil? && params[:search] != ''
		search = params[:search]

		#todo: include sku in search as well in future.
		@products = Product.find_by_sql("SELECT * from products WHERE name like '%"+search+"%'  LIMIT #{limit}
										OFFSET #{offset}")
		@products_result = []

		@products.each do |product|
		@product_hash = Hash.new
		@product_hash['id'] = product.id
		@product_hash['name'] = product.name
		@product_hash['status'] = product.status
    if product.product_inventory_warehousess.length > 0
      @product_hash['location'] = product.product_inventory_warehousess.first.location_primary
    else
      @product_hash['location'] = ''
    end

    if product.product_barcodes.length > 0
      @product_hash['barcode'] = product.product_barcodes.first.barcode
    else
      @product_hash['barcode'] = ''
    end
		if product.product_skus.length > 0
			@product_hash['sku'] = product.product_skus.first.sku
		else
			@product_hash['sku'] = ''
		end
		if product.product_cats.length > 0
			@product_hash['cat'] = product.product_cats.first.category
		else
			@product_hash['cat'] = ''
		end
		@product_hash['store_type'] = product.store.store_type

		@products_result.push(@product_hash)
		end

		@result['products'] = @products_result
	else
		@result['status'] = false
		@result['message'] = 'Improper search string'
	end


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def changeproductstatus
    @result = Hash.new
    @result['status'] = true
    if params[:select_all]
      #todo: implement search and filter by status
      @products = params[:productArray]
    else
      @products = params[:productArray]
    end
    unless @products.nil?
      @products.each do|product|
        @product = Product.find(product["id"])
        @product.status = product["status"]
        unless @product.save
          @result['status'] = false
        end
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def getdetails
  	@result = Hash.new
  	@product = Product.find_by_id(params[:id])

  	if !@product.nil?
  		@result['product'] = Hash.new
  		@result['product']['basicinfo'] = @product
  		@result['product']['skus'] = @product.product_skus
  		@result['product']['cats'] = @product.product_cats
    	@result['product']['images'] = @product.product_images
  		@result['product']['barcodes'] = @product.product_barcodes
      @result['product']['inventory_warehouses'] = @product.product_inventory_warehousess
      @result['product']['productkitskus'] = @product.product_kit_skuss

  		if @product.product_skus.length > 0
  			@result['product']['pendingorders'] = Order.where(:status=>'awaiting').where(:status=>'onhold').
  				where(:sku=>@product.product_skus.first.sku)
  		else
  			@result['product']['pendingorders'] = nil
  		end
  	end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def addskutokit
  	@result = Hash.new
  	@result['status'] = true
    @result['messages'] = []

  	@kit = Product.find_by_id(params[:kit_id])

  	if !@kit.is_kit
  		@result['messages'].push("Product with id="+@kit.id+"is not a kit")
  		@result['status'] &= false
  	else
  		if !params[:product_id].nil?
        item = Product.find_by_id(params[:product_id])
        if item.nil?
          @result['messages'].push("Item does not exist")
          @result['status'] &= false
        else
        @product_skus = item.product_skus
          if @product_skus.nil?
            @result['messages'].push("No sku found in item")
            @result['status'] &= false
          else
            product_kit_sku = ProductKitSkus.find_by_sku_and_product_id(@product_skus.first.sku,@kit.id)
            if product_kit_sku.nil?
              @productkitsku = ProductKitSkus.new
              @productkitsku.sku = @product_skus.first.sku
              @kit.product_kit_skuss << @productkitsku
              unless @kit.save
                @result['messages'].push("Could not save kit with sku: "+@product_skus.first.sku)
                @result['status'] &= false
              end
            else
              @result['messages'].push("The sku "+@product_skus.first.sku+" has already been added to the kit")
              @result['status'] &= false
            end
          end
        end
	  	else
	  		@result['messages'].push("No item sent in the request")
			  @result['status'] &= false
  		end
  	end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def removeskusfromkit
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    @result['asddddd'] = []
    @kit = Product.find_by_id(params[:kit_id])

    if @kit.is_kit
      if params[:kit_skus].nil?
        @result['messages'].push("No sku sent in the request")
        @result['status'] &= false
      else
        params[:kit_skus].reject!{|a| a==""}
        params[:kit_skus].each do |kit_sku|
          product_kit_sku = ProductKitSkus.find_by_sku_and_product_id(kit_sku,@kit.id)
          if product_kit_sku.nil?
            @result['messages'].push("Sku "+kit_sku+" not found in item")
            @result['status'] &= false
          else
            @result["asddddd"].push( product_kit_sku);
              unless product_kit_sku.destroy
                @result['messages'].push("sku "+kit_sku+"could not be removed fron kit")
                @result['status'] &= false
              end

          end
        end
      end
    else
      @result['messages'].push("Product with id="+@kit.id+"is not a kit")
      @result['status'] &= false
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end
  def updateproduct
  	@result = Hash.new
  	@product = Product.find(params[:basicinfo][:id])
  	@result['status'] = true
  	@result['params'] = params
  	if !@product.nil?

  		#Update Basic Info
  		@product.alternate_location = params[:basicinfo][:alternate_location]
  		@product.barcode = params[:basicinfo][:barcode]
  		@product.disable_conf_req = params[:basicinfo][:disable_conf_req]

  		@product.is_kit = params[:basicinfo][:is_kit]
  		@product.is_skippable = params[:basicinfo][:is_skippable]
  		@product.kit_parsing = params[:basicinfo][:kit_parsing]
  		@product.name = params[:basicinfo][:name]
  		@product.pack_time_adj = params[:basicinfo][:pack_time_adj]
  		@product.packing_placement = params[:basicinfo][:packing_placement]
  		@product.product_type = params[:basicinfo][:product_type]
  		@product.spl_instructions_4_confirmation =
  			params[:basicinfo][:spl_instructions_4_confirmation]
  		@product.spl_instructions_4_packer = params[:basicinfo][:spl_instructions_4_packer]
  		@product.status = params[:basicinfo][:status]
  		@product.store_id = params[:basicinfo][:store_id]
  		@product.store_product_id = params[:basicinfo][:store_product_id]

  		if !@product.save
  			@result['status'] &= false
  		end

  		#Update product inventory warehouses
  		#check if a product inventory warehouse is defined.
  		product_inv_whs = ProductInventoryWarehouses.where(:product_id=>@product.id)

  		if product_inv_whs.length > 0
	  		product_inv_whs.each do |inv_wh|
	  			found_inv_wh = false

	  			if !params[:inventory_warehouses].nil?
		  			params[:inventory_warehouses].each do |wh|
			  			if wh["id"] == inv_wh.id
			  				found_inv_wh = true
			  			end
		  			end
	  			end

	  			if found_inv_wh == false
	  				if !inv_wh.destroy
	  					@result['status'] &= false
	  				end
	  			end
	  		end
  		end

  		#Update product inventory warehouses
  		#check if a product category is defined.
  		if !params[:inventory_warehouses].nil?
	  		params[:inventory_warehouses].each do |wh|
	  			if !wh["id"].nil?
	  				product_inv_wh = ProductInventoryWarehouses.find(wh["id"])
	  				product_inv_wh.qty = wh["qty"]
	  				product_inv_wh.location_primary = wh["location_primary"]
	  				product_inv_wh.location_secondary = wh["location_secondary"]
	  				product_inv_wh.alert = wh["alert"]
	  				product_inv_wh.name = wh["name"]
			  		if !product_inv_wh.save
			  			@result['status'] &= false
			  		end
			  	else
			  		product_inv_wh = ProductInventoryWarehouses.new
            product_inv_wh.product_id = @product.id
	  				product_inv_wh.qty = wh["qty"]
	  				product_inv_wh.location_primary = wh["location_primary"]
	  				product_inv_wh.location_secondary = wh["location_secondary"]
	  				product_inv_wh.alert = wh["alert"]
	  				product_inv_wh.name = wh["name"]
			  		if !product_inv_wh.save
			  			@result['status'] &= false
			  		end
	  			end
	  		end
  		end


  		#Update product categories
  		#check if a product category is defined.
  		product_cats = ProductCat.where(:product_id=>@product.id)

  		if product_cats.length > 0
	  		product_cats.each do |productcat|
	  			found_cat = false

	  			if !params[:cats].nil?
		  			params[:cats].each do |cat|
			  			if cat["id"] == productcat.id
			  				found_cat = true
			  			end
		  			end
	  			end

	  			if found_cat == false
	  				if !productcat.destroy
	  					@result['status'] &= false
	  				end
	  			end
	  		end
  		end

  		if !params[:cats].nil?
	  		params[:cats].each do |category|
	  			if !category["id"].nil?
	  				product_cat = ProductCat.find(category["id"])
	  				product_cat.category = category["category"]
			  		if !product_cat.save
			  			@result['status'] &= false
			  		end
			  	else
			  		product_cat = ProductCat.new
			  		product_cat.category = category["category"]
			  		product_cat.product_id = @product.id
			  		if !product_cat.save
			  			@result['status'] &= false
			  		end
	  			end
	  		end
  		end

  		#Update product skus
  		#check if a product sku is defined.

  		product_skus = ProductSku.where(:product_id=>@product.id)

  		if product_skus.length > 0
	  		product_skus.each do |productsku|
	  			found_sku = false

	  			if !params[:skus].nil?
		  			params[:skus].each do |sku|
			  			if sku["id"] == productsku.id
			  				found_sku = true
			  			end
		  			end
	  			end
	  			if found_sku == false
	  				if !productsku.destroy
	  					@result['status'] &= false
	  				end
	  			end
	  		end
  		end
	  	if !params[:skus].nil?
	  		params[:skus].each do |sku|
	  			if !sku["id"].nil?
	  				product_sku = ProductSku.find(sku["id"])
	  				product_sku.sku = sku["sku"]
	  				product_sku.purpose = sku["purpose"]
			  		if !product_sku.save
			  			@result['status'] &= false
			  		end
			  	else
			  		product_sku = ProductSku.new
	  				product_sku.sku = sku["sku"]
	  				product_sku.purpose = sku["purpose"]
	  				product_sku.product_id = @product.id
			  		if !product_sku.save
			  			@result['status'] &= false
			  		end
	  			end
	  		end
  		end

  		#Update product barcodes
  		#check if a product barcode is defined.
  		product_barcodes = ProductBarcode.where(:product_id=>@product.id)

  		if product_barcodes.length > 0
	  		product_barcodes.each do |productbarcode|
	  			found_barcode = false

	  			if !params[:barcodes].nil?
		  			params[:barcodes].each do |barcode|
			  			if barcode["id"] == productbarcode.id
			  				found_barcode = true
			  			end
		  			end
	  			end

	  			if found_barcode == false
	  				if !productbarcode.destroy
	  					@result['status'] &= false
	  				end
	  			end
	  		end
  		end

  		#Update product barcodes
  		#check if a product barcode is defined
  		if !params[:barcodes].nil?
	  		params[:barcodes].each do |barcode|
	  			if !barcode["id"].nil?
	  				product_barcode = ProductBarcode.find(barcode["id"])
	  				product_barcode.barcode = barcode["barcode"]
			  		if !product_barcode.save
			  			@result['status'] &= false
			  		end
			  	else
			  		product_barcode = ProductBarcode.new
			  		product_barcode.barcode = barcode["barcode"]
			  		product_barcode.product_id = @product.id
			  		if !product_barcode.save
			  			@result['status'] &= false
			  		end
	  			end
	  		end
  		end

  		#Update product barcodes
  		#check if a product barcode is defined.
  		product_images = ProductImage.where(:product_id=>@product.id)

  		if product_images.length > 0
	  		product_images.each do |productimage|
	  			found_image = false

	  			if !params[:images].nil?
		  			params[:images].each do |image|
			  			if image["id"] == productimage.id
			  				found_image = true
			  			end
		  			end
	  			end

	  			if found_image == false
	  				if !productimage.destroy
	  					@result['status'] &= false
	  				end
	  			end
	  		end
  		end

  		#Update product barcodes
  		#check if a product barcode is defined
  		if !params[:images].nil?
	  		params[:images].each do |image|
	  			if !image["id"].nil?
	  				product_image = ProductImage.find(image["id"])
	  				product_image.image = image["image"]
	  				product_image.caption = image["caption"]
			  		if !product_image.save
			  			@result['status'] &= false
			  		end
			  	else
			  		product_image = ProductImage.new
			  		product_image.image = image["image"]
			  		product_image.caption = image["caption"]
			  		product_image.product_id = @product.id
			  		if !product_image.save
			  			@result['status'] &= false
			  		end
	  			end
	  		end
  		end
  	else
  		@result['status'] = false
  		@result['message'] = 'Cannot find product information.'
  	end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def updateproductlist
    @result = Hash.new
    @result['status'] = true
    @product = Product.find_by_id(params[:id])
    if @product.nil?
      @result['status'] = false
      @result['error_msg'] ="Cannot find Product"
    else
      if ["name","status"].include?(params[:var])
        @product[params[:var]] = params[:value]
        unless @product.save
          @result['status'] &= false
          @result['error_msg'] = "Couldn't save product info"
        end
      elsif params[:var] ==  "sku"
        @product_sku = @product.product_skus.first
        if @product_sku.nil?
          @product_sku = ProductSku.new
          @product_sku.product_id = params[:id]
        end
        @product_sku.sku = params[:value]
        unless @product_sku.save
          @result['status'] &= false
          @result['error_msg'] = "Couldn't save product info"
        end
      elsif params[:var] ==  "cat"
        @product_cat = @product.product_cats.first
        if @product_cat.nil?
          @product_cat = ProductCat.new
          @product_cat.product_id = params[:id]
        end
        @product_cat.category = params[:value]
        unless @product_cat.save
          @result['status'] &= false
          @result['error_msg'] = "Couldn't save product info"
        end
      elsif params[:var] ==  "barcode"
        @product_barcode = @product.product_barcodes.first
        if @product_barcode.nil?
          @product_barcode = ProductBarcode.new
          @product_barcode.product_id = params[:id]
        end
        @product_barcode.barcode = params[:value]
        unless @product_barcode.save
          @result['status'] &= false
          @result['error_msg'] = "Couldn't save product info"
        end
      elsif ["location" ,"location_secondary","location_name","qty"].include?(params[:var])
        @product_location = @product.product_inventory_warehousess.first
        if @product_location.nil?
          @product_location = ProductInventoryWarehouses.new
          @product_location.product_id = params[:id]
        end
        if params[:var] == "location"
          @product_location.location_primary = params[:value]
        elsif params[:var] == "location_secondary"
          @product_location.location_secondary = params[:value]
        elsif params[:var] == "location_name"
          @product_location.name = params[:value]
        elsif params[:var] == "qty"
          @product_location.qty = params[:value]
        end
        unless @product_location.save
          @result['status'] &= false
          @result['error_msg'] = "Couldn't save product info"
        end
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

	#This action will remove the entry for this product (the Alias) and the SKU of this new
	#product will be added to the list of skus for the existing product that the user is linking it to.
	#Any product can be turned into an alias, it doesn’t have to have the status of new, although most if the time it probably will.
	#The operation can not be undone.
	#If you had a situation where the newly imported product was actually the one you wanted to keep you could
	#find the original product and make it an alias of the new product...
  def setalias
  	@result = Hash.new
  	@result['status'] = true
  	@result['messages'] = []

  	@product_orig = Product.find(params[:product_orig_id])
  	@product_alias = Product.find(params[:product_alias_id])

  	#all SKUs of the alias will
  	@product_alias.product_skus.each do |alias_sku|
  		alias_sku.product_id = @product_orig.id
  		if !alias_sku.save
  			result['status'] &= false
  			result['messages'].push('Error saving Sku for sku id'+alias_sku.id)
  		end
  	end

  	@product_barcodes = ProductBarcode.where(:product_id=>@product_alias.id)
  	@product_barcodes.each do |alias_barcode|
  		alias_barcode.product_id = @product_orig.id
  		if !alias_barcode.save
  			result['status'] &= false
  			result['messages'].push('Error saving Barcode for barcode id'+alias_barcode.id)
  		end
  	end

  	#destroy the aliased object
  	if !@product_alias.destroy
  		result['status'] &= false
  		result['messages'].push('Error deleting the product alias id:'+@product_alias.id)
  	end

  	respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def addimage
  	@result = Hash.new
  	@result['status'] = true
  	@result['messages'] = []

  	@product = Product.find(params[:product_id])
  	if !@product.nil? && !params[:product_image].nil?
	  	@image = ProductImage.new

        csv_directory = "public/images"
        file_name = Time.now.to_s+params[:product_image].original_filename
        path = File.join(csv_directory, file_name )
        File.open(path, "wb") { |f| f.write(params[:product_image].read) }
       	@image.image = "/images/"+file_name
	  	@image.caption = params[:caption] if !params[:caption].nil?
	  	@product.product_images << @image
	  	if !@product.save
	  		@result['status'] = false
	  		@result['messages'].push("Adding image failed")
	  	end
	else
	  	@result['status'] = false
	  	@result['messages'].push("Invalid data sent to the server")
	end

  	respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  
  end

end
