namespace :db do

  desc "add weight to all products in the database"
  task :weights_migration => :environment do

  	#for all stores
  	stores = Store.all
  	stores.each do |store|
  	# if store type is magento
  	# for each product in magento
  	# use the call from magento import and import the weight attribute

  		# if store type is ebay
	  	if store.store_type == 'Ebay'
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
			end
		end
  	
  	

  	# if store type is amazon
  	# for each product in amazon
  	#use the call from amazon import and import the weight attribute


  end
end