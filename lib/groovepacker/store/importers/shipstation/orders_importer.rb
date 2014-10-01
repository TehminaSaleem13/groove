module Groovepacker
  module Store
    module Importers
      module Shipstation
        include ProductsHelper
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = self.build_result

            begin
              #import only those products that have been created after the last_imported_at time
              if credential.last_imported_at.nil?
                orders = client.order.where('OrderStatusID' => 2)
              else
                orders = client.order.where('CreateDate' => credential.last_imported_at, 'OrderStatusID' => 2)
              end
              importing_time = DateTime.now
              # result[:total_imported] = orders.length
              unless orders.nil?
                result[:total_imported] = orders.length
                orders.each do |order|
                  if Order.where(:increment_id=>order.order_number).length == 0
                    shipstation_order = Order.new
                    shipstation_order.store = credential.store
                    import_order(shipstation_order, order)

                    order_items = client.order_items.where("order_id"=>order.order_id)
                    unless order_items.nil?
                      order_items.each do |item|
                        order_item = OrderItem.new
                        import_order_item(order_item, item)
  
                        Rails.logger.info("SKU Product Id: " + item.to_s) 

                        if item.sku.nil? or item.sku == ''
                          # if sku is nil or empty
                          if Product.find_by_name(item.description).nil?
                            # if item is not found by name then create the item
                            order_item.product = create_new_product_from_order(item, credential.store, ProductSku.get_temp_sku)
                          else
                            # product exists add temp sku if it does not exist
                            products = Product.where(name: item.description)
                            unless contains_temp_skus(products)
                              order_item.product = create_new_product_from_order(item, credential.store, ProductSku.get_temp_sku)
                            else
                              order_item.product = get_product_with_temp_skus(products)
                            end
                          end
                        elsif ProductSku.where(:sku=>item.sku).length == 0
                          # if non-nil sku is not found
                          product = create_new_product_from_order(item, credential.store, item.sku)
                          Groovepacker::Store::Importers::Shipstation::
                            ProductsImporter.new(handler).import_single({ 
                              product_sku: item.sku,
                              product_id: product.id,
                              handler: handler
                            })
                          order_item.product = product
                        else
                          order_item_product = ProductSku.where(:sku=>item.sku).
                          first.product
                          
                          unless item.thumbnail_url.nil?
                            if order_item_product.product_images.length == 0
                              image = ProductImage.new
                              image.image = item.thumbnail_url
                              order_item_product.product_images << image
                            end
                          end
                          order_item_product.save
                          order_item.product = order_item_product
                        end
      
                        shipstation_order.order_items << order_item
                      end
                    end
                    if shipstation_order.save
                      shipstation_order.addactivity("Order Import", credential.store.name+" Import")
                      shipstation_order.order_items.each do |item|
                        unless item.product.nil? || item.product.primary_sku.nil?
                          shipstation_order.addactivity("Item with SKU: "+item.product.primary_sku+" Added", credential.store.name+" Import")
                        end
                      end
                      shipstation_order.set_order_status
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
              puts e.backtrace.join("\n")
            end

            if result[:status]
              credential.last_imported_at = importing_time
              credential.save
            end
            result
          end

          def import_order(shipstation_order, order)
            shipstation_order.increment_id = order.order_number
            shipstation_order.seller_id = order.seller_id
            shipstation_order.order_status_id = order.order_status_id
            shipstation_order.order_placed_time = order.order_date 
            split_name = order.ship_name.split(' ')
            shipstation_order.lastname = split_name.pop
            shipstation_order.firstname = split_name.join(' ')
            shipstation_order.email = order.buyer_email unless order.buyer_email.nil?
            shipstation_order.address_1 = order.ship_street1
            shipstation_order.address_2 = order.ship_street2 unless order.ship_street2.nil?
            shipstation_order.city = order.ship_city
            shipstation_order.state = order.ship_state
            shipstation_order.postcode = order.ship_postal_code unless order.ship_postal_code.nil?
            shipstation_order.country = order.ship_country_code 
            shipstation_order.shipping_amount = order.shipping_amount unless order.shipping_amount.nil?
            shipstation_order.order_total = order.order_total
            shipstation_order.notes_from_buyer = order.notes_from_buyer unless order.notes_from_buyer.nil?
            shipstation_order.weight_oz = order.weight_oz unless order.weight_oz.nil?
          end

          def import_order_item(order_item, item)
            order_item.sku = item.sku unless item.sku.nil?
            order_item.qty = item.quantity
            order_item.price = item.unit_price
            order_item.name = item.description
            order_item.row_total = item.unit_price.to_f * 
            item.quantity.to_i
            order_item.product_id = item.product_id unless item.product_id.nil?
            order_item.order_id = item.order_id
          end

          def create_new_product_from_order(item, store, sku)
            #create and import product
            product = Product.create(name: item.description, store: store,
              store_product_id: 0)
            product.product_skus.create(sku: sku)
            #Build Image
            unless item.thumbnail_url.nil? || product.product_images.length > 0
              product.product_images.create(image: item.thumbnail_url)
            end                          

            #build barcode
            unless item.upc.nil? || product.product_barcodes.length > 0
              product.product_barcodes.create(barcode: item.upc)
            end
            product
          end

          def import_single(hash)
            {}
          end
        end
      end
    end
  end
end