class EbayCredentials < ActiveRecord::Base
  
  attr_accessible :auth_token, :productauth_token, :import_products, :import_images, :ebay_auth_expiration
  belongs_to :store
  def get_signinurl
	require 'eBayAPI'
  
	@eBay = EBay::API.new(self.auth_token, 
	    ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'], 
	    ENV['EBAY_CERT_ID'], :sandbox=>true)

	@signinurl = "https://signin.sandbox.ebay.com/ws/eBayISAPI.dll?SignIn&runame="+
	              "Navaratan_Techn-Navarata-607d-4-ltqij&SessID="+session_id
  end

  def get_token

  end

  def import_product_by_sku (sku, store_id)
		@credential = self
		@result = Hash.new

		if !@credential.nil?
			require 'eBayAPI'
			if ENV['EBAY_SANDBOX_MODE'] == 'YES'
				sandbox = true
			else
				sandbox = false
			end
			@eBay = EBay::API.new(@credential.productauth_token,
				        ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
        				ENV['EBAY_CERT_ID'], :sandbox=>sandbox)
			# skuArray = []
			# sku = Hash.new
			# sku['sKU'] = sku
			# skuArray.push(sku)

			seller_list =@eBay.GetSellerList(:startTimeFrom=> (Date.today - 3.months).to_datetime,
				 :startTimeTo =>(Date.today + 1.day).to_datetime)

			@result['total_imported']  = seller_list.itemArray.length
			puts "Total imported is: " + seller_list.itemArray.length.to_s
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
						@productdb.store_id = store_id

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
							end
						end
					end
				end
			end while(page_num <= total_pages)
		end
  end
end
