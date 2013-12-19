module ProductsHelper
	#requires a product is created with appropriate seller sku
	def import_amazon_product_details(mws, credential, product_id)
		#send request to amazon mws get matching product API
		seller_sku = '12345678'
		response = mws.products.get_matching_product_for_id :id_type=>'SellerSKU', :seller_sku => [seller_sku]
		products = response.products
		#store the details in the product db.
		products.each do |product|
			puts product
		end
	end
end
