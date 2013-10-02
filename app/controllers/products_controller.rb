class ProductsController < ApplicationController

	def importproducts
	@store = Store.find(params[:id])
	@result = Hash.new

	@result['status'] = true
	@result['messages'] = []
	@result['total_imported'] = 0
	@result['success_imported'] = 0
	@result['previous_imported'] = 0

	#import if magento products
	if @store.store_type == 'Magento' then
		@magento_credentials = MagentoCredentials.where(:store_id => @store.id)

		if @magento_credentials.length > 0
			client = Savon.client(wsdl: @magento_credentials.first.producthost+"/index.php/api/soap/index/wsdl/1")
			
			if !client.nil?
				
				response = client.call(:login,  message: { apiUser: @magento_credentials.first.productusername, 
					apikey: @magento_credentials.first.productapi_key })

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

								#add productdb sku
								@productdbsku = ProductSku.new
								@productdbsku.sku = result_product['sku']
								@productdbsku.purpose = 'primary'

								#publish the sku to the product record
								@productdb.product_skus << @productdbsku

								#save
								if @productdb.save
									@result['success_imported'] = @result['success_imported'] + 1
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
			@eBay = EBay::API.new(@credential.productauth_token, 
				        ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'], 
        				ENV['EBAY_CERT_ID'], :sandbox=>true)
			
			seller_list =@eBay.GetSellerList(:startTimeFrom=> (Date.today - 3.months).to_datetime,
				 :startTimeTo =>(Date.today + 1.day).to_datetime)
			
			@result['total_imported']  = seller_list.itemArray.length

			seller_list.itemArray.each do |item|
				#add product to the database
			if Product.where(:store_product_id=>item.itemID).length  == 0
				@productdb = Product.new
				@item = @eBay.getItem(:ItemID => item.itemID).item
				@sku = "not_used"
				@productdb.name = @item.title
				@productdb.store_product_id = item.itemID
				@productdb.product_type = 'not_used'
				@productdb.store = @store

				#add productdb sku
				@productdbsku = ProductSku.new
		
					@productdbsku.sku = @sku

				@productdbsku.purpose = 'primary'

				#publish the sku to the product record
				@productdb.product_skus << @productdbsku

				#save
				if @productdb.save
					@result['success_imported'] = @result['success_imported'] + 1
				end
			else
				@result['previous_imported'] = @result['previous_imported'] + 1
			end
			end

		end
	elsif @store.store_type == 'Amazon'
		@amazon_credentials = AmazonCredentials.where(:store_id => @store.id)

		if @amazon_credentials.length > 0 
			@credential = @amazon_credentials.first
			mws = MWS.new(:aws_access_key_id => ENV['AMAZON_MWS_ACCESS_KEY_ID'],
			  :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
			  :seller_id => @credential.productmerchant_id,
			  :marketplace_id => @credential.productmarketplace_id)
			#@result['aws-response'] = mws.reports.request_report :report_type=>'_GET_MERCHANT_LISTINGS_DATA_'
			#@result['aws-rewuest_status'] = mws.reports.get_report_request_list
			response = mws.reports.get_report :report_id=> params[:reportid]
			 			#@result['report_id'] = response.body
			
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
						@productdb.store = @store

						#add productdb sku
						@productdbsku = ProductSku.new
						@productdbsku.sku = product_row[3]
						@productdbsku.purpose = 'primary'

						#publish the sku to the product record
						@productdb.product_skus << @productdbsku
						#save
						if @productdb.save
							@result['success_imported'] = @result['success_imported'] + 1
						end
					else
						@result['previous_imported'] = @result['previous_imported'] + 1
					end
			  	end
			end
		end


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
		  	  :seller_id => @credential.productmerchant_id,
			  :marketplace_id => @credential.productmarketplace_id)

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
			  :seller_id => @credential.productmerchant_id,
			  :marketplace_id => @credential.productmarketplace_id)

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

	def getproducts
		@products = Product.where('id < 10')
		@products_result = []

		@products.each do |product|
		@product_hash = Hash.new

		@product_hash['name'] = product.name
		@product_hash['sku'] = 'SKU1'
		@product_hash['store_type'] = product.store.store_type

		@products_result.push(@product_hash)
		end

		respond_to do |format|
      		format.json { render json: @products_result}
    	end
	end
end
