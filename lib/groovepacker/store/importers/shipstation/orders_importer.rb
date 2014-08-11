module Groovepacker
  module Store
    module Importers
      module Shipstation
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = self.build_result

            begin
              orders = client.order.where('OrderStatusID' => 2)
              result[:total_imported] = orders.length

              if !orders.nil?
                result[:total_imported] = orders.length
                orders.each do |order|
                  Product.where(:status => 'new')
                  if Order.where(:increment_id=>order.order_id.to_s).length == 0
                    @order = Order.new
                    @order.increment_id = order.OrderID
                    @order.firstname = order.Name
                    @order.company = order.Company
                    @order.address_1 = order.Street1
                    @order.address_2 = order.Street2
                    @order.city = order.City
                    @order.state = order.State
                    @order.postcode = order.PostalCode
                    @order.country = order.CountryCode
                    @order.store = credential.store

                    order_items = client.order_items.where("order_id"=>order.OrderID)
                    if !order_items.nil?
                      order_items.each do |item|
                        @order_item = OrderItem.new
                        @order_item.sku = item.SKU
                        @order_item.qty = item.Quantity
                        @order_item.price = item.UnitPrice
                        @order_item.row_total = item.UnitPrice.to_f * 
                        item.Quantity.to_i
                        @order_item.product_id = item.ProductID
                        @order_item.order_id = item.OrderID
                        if ProductSku.where(:sku=>item.SKU).length == 0
                          #create and import product
                          product = Product.new
                          product.name = 'New imported item'
                          product.store_product_id = 0
                          product.store = credential.store

                          sku = ProductSku.new
                          sku.sku = item.SKU
                          product.product_skus << sku

                          #Build Image
                          unless item.ThumbnailUrl.nil?
                            image = ProductImage.new
                            image.image = item.ThumbnailUrl
                            product.product_images << image
                          end                          

                          #build barcode
                          unless item.UPC.nil?
                            barcode = ProductBarcode.new
                            barcode.barcode = item.UPC
                            product.product_barcodes << barcode
                          end
                          product.save
                          #import other product details
                          Groovepacker::Store::Importers::Shipstation::
                            ProductsImporter.new(handler).import_single({ 
                              product_sku: item.SKU,
                              product_id: product.id,
                              handler: handler
                            })
                        else
                          @order_item.product = ProductSku.where(:sku=>item.SKU).
                          first.product
                        end
                      end
                      @order.order_items << @order_item
                    end
                    if @order.save
                      if !@order.addnewitems
                        result[:status] &= false
                        result[:messages].push('Problem adding new items')
                      end
                      @order.addactivity("Order Import", credential.store.name+" Import")
                      @order.order_items.each do |item|
                        @order.addactivity("Item with SKU: "+item.sku+" Added", credential.store.name+" Import")
                      end
                      @order.set_order_status
                      result[:success_imported] = result[:success_imported] + 1
                    end
                  else
                      result[:previous_imported] = result[:previous_imported] + 1
                  end
                end
              end
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e.message)
              puts "Exception"
              puts e.message.inspect
            end
            result
          end

          def import_single(hash)
            {}
          end  
        end
      end
    end
  end
end