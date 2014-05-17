require 'debugger'
include ProductsHelper
namespace :db do
  desc "add weight to all products in the database"
  task :weights_migration => :environment do

  	#for all stores
  	stores = Store.all
  	stores.each do |store|
  		#if store type is magento
	  	if store.store_type == 'Magento'
	  		@magento_credentials = 
	  			MagentoCredentials.where(:store_id => store.id)
	  		if @magento_credentials.length > 0
					client = Savon.client(wsdl: @magento_credentials.first.host+"/index.php/api/soap/index/wsdl/1")
					if !client.nil?
						response = client.call(:login,  message: { apiUser: @magento_credentials.first.username,
						apikey: @magento_credentials.first.api_key })

						if response.success?
							session =  response.body[:login_response][:login_return]
							products = store.products
							# for each product in magento
							products.each do |product|
								if !product.store_product_id.nil?
									get_product_info = client.call(:call, 
													message: {session: session,
													method: 'catalog_product.info',
													product: product.store_product_id})
									if !get_product_info.nil?
										product_info = 
													get_product_info.body[:call_response][:call_return][:item]
										# use the call from magento import and import the weight attribute
										product_info.each do |product_info_item|
											if product_info_item[:key] == 'weight'

												if product_info_item[:value] != nil
													product.weight = product_info_item[:value] * 16
													product.save
												end
											end
										end
									end
								end
							end
						end
					end
				end
  		# if store type is ebay
	  	elsif store.store_type == 'Ebay'
				#do ebay connect.
				@ebay_credentials = EbayCredentials.where(:store_id => store.id)
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
					products = store.products
					# for each product in ebay
					products.each do |product|
						#use the call from ebay import and import the weight attribute
						@item = @eBay.getItem(:ItemID => product.store_product_id)
						if !@item.nil? 
							@item = @item.item
							if !@item.nil?
								weight_lbs = @item.shippingDetails.calculatedShippingRate.weightMajor
								weight_oz = @item.shippingDetails.calculatedShippingRate.weightMinor
								product.weight = weight_lbs * 16 + weight_oz
								product.save
							end
						end
					end
				end
			#if store type is amazon
			elsif store.store_type == 'Amazon'
				products = store.products
				# puts "products"
				# puts products.inspect
				# for each product in amazon
				products.each do |product|
					product_skus = product.product_skus
					# puts "product_skus:"
					# puts product_skus
					product_skus.each do |product_sku|
						#use the call from amazon import and import the weight attribute
						import_amazon_product_details(store.id, product_sku, product.id)
					end
				end
			end
  	end
  end
end