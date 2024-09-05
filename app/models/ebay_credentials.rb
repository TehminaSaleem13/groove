# frozen_string_literal: true

class EbayCredentials < ApplicationRecord
  # attr_accessible :auth_token, :productauth_token, :import_products, :import_images, :ebay_auth_expiration, :shipped_status, :unshipped_status
  belongs_to :store

  def get_signinurl
    require 'eBayAPI'

    @eBay = EBay::API.new(auth_token,
                          ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
                          ENV['EBAY_CERT_ID'], sandbox: true)

    @signinurl = 'https://signin.sandbox.ebay.com/ws/eBayISAPI.dll?SignIn&runame=' \
                 'Navaratan_Techn-Navarata-607d-4-ltqij&SessID=' + session_id
  end

  def get_token; end

  def import_product_by_sku(_sku, store_id)
    @credential = self
    @result = {}

    unless @credential.nil?
      require 'eBayAPI'
      sandbox = ENV['EBAY_SANDBOX_MODE'] == 'YES'
      @eBay = EBay::API.new(@credential.productauth_token,
                            ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
                            ENV['EBAY_CERT_ID'], sandbox: sandbox)
      # skuArray = []
      # sku = Hash.new
      # sku['sKU'] = sku
      # skuArray.push(sku)

      seller_list = @eBay.GetSellerList(startTimeFrom: (Date.today - 3.months).to_datetime,
                                        startTimeTo: (Date.today + 1.day).to_datetime)

      @result['total_imported'] = seller_list.itemArray.length
      total_pages = (@result['total_imported'] / 10) + 1
      page_num = 1
      begin
        seller_list = @eBay.GetSellerList(startTimeFrom: (Date.today - 3.months).to_datetime,
                                          startTimeTo: (Date.today + 1.day).to_datetime, detailLevel: 'ReturnAll',
                                          pagination: { entriesPerPage: '10', pageNumber: page_num })
        page_num += 1
        seller_list.itemArray.each do |item|
          # add product to the database
          next unless Product.where(store_product_id: item.itemID).empty?

          @productdb = Product.new
          @item = @eBay.getItem(ItemID: item.itemID).item
          @productdb.name = @item.title
          @productdb.store_product_id = item.itemID
          @productdb.product_type = 'not_used'
          @productdb.status = 'Inactive'
          @productdb.store_id = store_id

          # add productdb sku
          @productdbsku = ProductSku.new
          @productdbsku.sku = if @item.sKU.nil?
                                'not_available'
                              else
                                @item.sKU
                              end
          # @item.productListingType.uPC
          @productdbsku.purpose = 'primary'

          # publish the sku to the product record
          @productdb.product_skus << @productdbsku

          unless @item.pictureDetails.nil?
            if !@item.pictureDetails.pictureURL.nil? &&
               !@item.pictureDetails.pictureURL.empty?
              @productimage = ProductImage.new
              @productimage.image = 'http://i.ebayimg.com' +
                                    @item.pictureDetails.pictureURL.first.request_uri
              @productdb.product_images << @productimage

            end

            unless @item.primaryCategory.nil?
              @product_cat = ProductCat.new
              @product_cat.category = @item.primaryCategory.categoryName
              @productdb.product_cats << @product_cat
            end

            unless @item.secondaryCategory.nil?
              @product_cat = ProductCat.new
              @product_cat.category = @item.secondaryCategory.categoryName
              @productdb.product_cats << @product_cat
            end
          end

          if ProductSku.where(sku: @item.sKU).empty?
            # save
            @productdb.set_product_status if @productdb.save
          end
        end
      end while (page_num <= total_pages)
    end
  end
end
