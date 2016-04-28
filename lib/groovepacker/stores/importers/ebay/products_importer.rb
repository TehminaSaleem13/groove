module Groovepacker
  module Stores
    module Importers
      module Ebay
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            #do ebay connect.
            handler = self.get_handler
            credential = handler[:credential]
            ebay = handler[:store_handle]
            result = self.build_result

            seller_list = ebay.GetSellerList(
              :startTimeFrom => (Date.today - 3.months).to_datetime,
              :startTimeTo => (Date.today + 1.day).to_datetime)

            result[:total_imported] = seller_list.itemArray.length
            total_pages = (result[:total_imported] / 10) +1
            page_num = 1

            begin
              seller_list = ebay.GetSellerList(
                :startTimeFrom => (Date.today - 3.months).to_datetime,
                :startTimeTo => (Date.today + 1.day).to_datetime,
                :detailLevel => 'ReturnAll',
                :pagination => {:entriesPerPage => '10',
                                :pageNumber => page_num})

              page_num = page_num + 1

              seller_list.itemArray.each do |item|
                #add product to the database
                if Product.where(:store_product_id => item.itemID).length == 0
                  #hash includes itemID, sku, ebay, credential
                  result_product_id = self.import_single({
                                                           itemID: item.itemID,
                                                           sku: nil,
                                                           ebay: ebay,
                                                           credential: credential},
                                                         true)

                  if result_product_id > 0
                    result[:success_imported] = result[:success_imported] + 1
                  else
                    result[:previous_imported] = result[:previous_imported] + 1
                  end
                else
                  result[:previous_imported] = result[:previous_imported] + 1
                end
              end
            end while (page_num <= total_pages)
            result
          end

          #hash includes itemID, sku, ebay, credential
          def import_single(input_hash, sku_check_override = false)
            sku = input_hash[:sku]
            ebay = input_hash[:ebay]
            credential = input_hash[:credential]
            itemID = input_hash[:itemID]

            product_id = 0
            if ProductSku.where(:sku => input_hash[:sku]).length == 0 ||
              sku_check_override
              @item = ebay.getItem(:ItemID => itemID).item
              @productdb = Product.new
              @productdb.name = @item.title
              @productdb.store_product_id = @item.itemID
              @productdb.product_type = 'not_used'
              @productdb.status = 'inactive'
              @productdb.store = credential.store

              unless @item.shippingDetails.nil? ||
                @item.shippingDetails.calculatedShippingRate.nil?

                weight_lbs =
                  @item.shippingDetails.calculatedShippingRate.weightMajor.to_i unless @item.shippingDetails.calculatedShippingRate.weightMajor.nil?

                weight_oz =
                  @item.shippingDetails.calculatedShippingRate.weightMinor.to_i unless @item.shippingDetails.calculatedShippingRate.weightMinor.nil?

                @productdb.weight = weight_lbs * 16 + weight_oz
              end

              #add productdb sku
              @productdbsku = ProductSku.new
              if @item.sKU.nil?
                @productdbsku.sku = "not_available"
              else
                @productdbsku.sku = @item.sKU
              end
              #@item.productListingType.uPC
              @productdbsku.purpose = 'primary'

              #publish the sku to the product record
              @productdb.product_skus << @productdbsku

              if credential.import_images
                if !@item.pictureDetails.nil?
                  if !@item.pictureDetails.pictureURL.nil? &&
                    @item.pictureDetails.pictureURL.length > 0
                    @productimage = ProductImage.new
                    @productimage.image = "http://i.ebayimg.com" +
                      @item.pictureDetails.pictureURL.first.request_uri()
                    @productdb.product_images << @productimage
                  end
                end
              end

              if credential.import_products
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

              #add inventory warehouse
              inv_wh = ProductInventoryWarehouses.new
              inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
              @productdb.product_inventory_warehousess << inv_wh

              @productdb.save
              make_product_intangible(@productdb)
              @productdb.set_product_status
              product_id = @productdb.id
            else
              product_id = ProductSku.where(:sku => input_hash[:sku]).first.product_id
            end

            product_id
          end
        end
      end
    end
  end
end
