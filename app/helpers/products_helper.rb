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

				product.save
				product.update_product_status
			end
		rescue Exception => e
		end
	end
end
