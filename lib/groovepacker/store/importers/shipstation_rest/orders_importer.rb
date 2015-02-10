module Groovepacker
  module Store
    module Importers
      module ShipstationRest
        include ProductsHelper
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            import_item = handler[:import_item]
            result = self.build_result

            statuses = []
            statuses.push('awaiting_shipment') if credential.shall_import_awaiting_shipment?
            statuses.push('shipped') if credential.shall_import_shipped?
            unless statuses.empty?
              response = client.get_orders(statuses.join(","), credential.last_imported_at)
              importing_time = Date.today - 1.day

              unless response["orders"].nil?   
                result[:total_imported] = response["orders"].length          
                import_item.current_increment_id = ''
                import_item.success_imported = 0
                import_item.previous_imported = 0
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.to_import = result[:total_imported]
                import_item.save
                response["orders"].each do |order|
                  import_item.current_increment_id = order["orderNumber"]
                  import_item.current_order_items = -1
                  import_item.current_order_imported_item = -1
                  import_item.save
                  if Order.where(increment_id: order["orderNumber"]).length == 0
                    shipstation_order = Order.new
                    ship_to = order["shipTo"]["name"].split(" ")
                    import_order(shipstation_order, order)
                    
                    unless order["items"].nil?
                      import_item.current_order_items = order["items"].length
                      import_item.current_order_imported_item = 0
                      import_item.save
                      order["items"].each do |item|
                        order_item = OrderItem.new
                        import_order_item(order_item, item)

                        Rails.logger.info("SKU Product Id: " + item.to_s) 

                        if item["sku"].nil? or item["sku"] == ''
                          # if sku is nil or empty
                          if Product.find_by_name(item["name"]).nil?
                            # if item is not found by name then create the item
                            order_item.product = create_new_product_from_order(item, credential.store, ProductSku.get_temp_sku)
                          else
                            # product exists add temp sku if it does not exist
                            products = Product.where(name: item["name"])
                            unless contains_temp_skus(products)
                              order_item.product = create_new_product_from_order(item, credential.store, ProductSku.get_temp_sku)
                            else
                              order_item.product = get_product_with_temp_skus(products)
                            end
                          end
                        elsif ProductSku.where(sku: item["sku"]).length == 0
                          # if non-nil sku is not found
                          product = create_new_product_from_order(item, credential.store, item["sku"])
                          order_item.product = product
                        else
                          order_item_product = ProductSku.where(sku: item["sku"]).
                          first.product
                          
                          unless item["imageUrl"].nil?
                            if order_item_product.product_images.length == 0
                              image = ProductImage.new
                              image.image = item["imageUrl"]
                              order_item_product.product_images << image
                            end
                          end
                          order_item_product.save
                          order_item.product = order_item_product
                        end
      
                        shipstation_order.order_items << order_item
                        import_item.current_order_imported_item = import_item.current_order_imported_item + 1
                        import_item.save
                      end
                    end
                    if shipstation_order.save
                      shipstation_order.addactivity("Order Import", credential.store.name+" Import")
                      shipstation_order.order_items.each do |item|
                        unless item.product.nil? || item.product.primary_sku.nil?
                          shipstation_order.addactivity("Item with SKU: "+item.product.primary_sku+" Added", credential.store.name+" Import")
                        end
                      end
                      shipstation_order.store = credential.store
                      shipstation_order.save
                      shipstation_order.set_order_status
                      result[:success_imported] = result[:success_imported] + 1
                      import_item.success_imported = result[:success_imported]
                      import_item.save
                    end
                  else
                    import_item.previous_imported = import_item.previous_imported + 1
                    import_item.save
                    result[:previous_imported] = result[:previous_imported] + 1
                  end
                end
              end
            else
              result[:status] = false
              result[:messages].push(
                'Cannot import orders as none of the statuses are chosen in the store modal')
            end
            if result[:status]
              credential.last_imported_at = importing_time
              credential.save
            end
            result
          end

          def import_order(shipstation_order, order)
            shipstation_order.increment_id = order["orderNumber"]
            shipstation_order.order_placed_time = order["orderDate"]
            shipstation_order.email = order["customerEmail"] unless order["customerEmail"].nil?
            unless order["shipTo"].nil?
              unless order["shipTo"]["name"].nil?
                split_name = order["shipTo"]["name"].split(' ')
                shipstation_order.lastname = split_name.pop
                shipstation_order.firstname = split_name.join(' ')
              end

              shipstation_order.address_1 = order["shipTo"]["street1"] unless order["shipTo"]["street1"].nil?
              shipstation_order.address_2 = order["shipTo"]["street2"] unless order["shipTo"]["street2"].nil?
              shipstation_order.city = order["shipTo"]["city"] unless order["shipTo"]["city"].nil?
              shipstation_order.state = order["shipTo"]["state"] unless order["shipTo"]["state"].nil?
              shipstation_order.postcode = order["shipTo"]["postalCode"] unless order["shipTo"]["postalCode"].nil?
              shipstation_order.country = order["shipTo"]["country"] unless order["shipTo"]["country"].nil?
            end

            shipstation_order.shipping_amount = order["shippingAmount"] unless order["shippingAmount"].nil?
            shipstation_order.order_total = order["amountPaid"] unless order["amountPaid"].nil?
            shipstation_order.notes_from_buyer = order["customerNotes"] unless order["customerNotes"].nil?
            shipstation_order.weight_oz = order["weight"]["value"] unless order["weight"].nil? || order["weight"]["value"].nil?
          end

          def import_order_item(order_item, item)
            order_item.qty = item["quantity"]
            order_item.price = item["unitPrice"]
            order_item.row_total = item["unitPrice"].to_f * 
            item["quantity"].to_f
            order_item
          end

          def create_new_product_from_order(item, store, sku)
            #create and import product
            product = Product.create(name: item["name"], store: store,
              store_product_id: 0)
            product.product_skus.create(sku: sku)
            #Build Image
            unless item["imageUrl"].nil? || product.product_images.length > 0
              product.product_images.create(image: item["imageUrl"])
            end
            product
          end
        end
      end
    end
  end
end
