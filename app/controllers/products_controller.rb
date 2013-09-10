class ProductsController < ApplicationController

	def importproducts
	@store = Store.find(params[:id])
	@result = Hash.new

	@result['status'] = true
	@result['messages'] = []
	@result['total_imported'] = 0
	@result['success_imported'] = 0

	#import if magento products
	if @store.store_type == 'Magento' then
		@magento_credentials = MagentoCredentials.where(:store_id => @store.id)

		if @magento_credentials.length > 0
			client = Savon.client(wsdl: @magento_credentials.first.producthost+"/api/?wsdl")
			
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
	elsif @store.store_type = 'Ebay'
		#do ebay connect.
		@ebay_credentials = EbayCredentials.where(:store_id => @store.id)

		if @ebay_credentials.length > 0 
			@credential = @ebay_credentials.first
			require 'eBayAPI'
			
			@eBay = EBay::API.new(@credential.productauth_token, 
				@credential.productdev_id, @credential.productapp_id, @credential.productcert_id, :sandbox=>true)
			
			seller_list =@eBay.GetSellerList(:startTimeFrom=> (Date.today - 3.months).to_datetime,
				 :startTimeTo =>(Date.today + 1.day).to_datetime)
			
			@result['total_imported']  = seller_list.itemArray.length

			seller_list.itemArray.each do |item|
				#add product to the database
				@productdb = Product.new
				@productdb.name = @eBay.getItem(:ItemID => item.itemID).item.title
				@productdb.store_product_id = item.itemID
				@productdb.product_type = 'not_used'
				@productdb.store = @store

				#add productdb sku
				@productdbsku = ProductSku.new
				@productdbsku.sku = 'not_used'
				@productdbsku.purpose = 'primary'

				#publish the sku to the product record
				@productdb.product_skus << @productdbsku

				#save
				if @productdb.save
					@result['success_imported'] = @result['success_imported'] + 1
				end
			end

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
