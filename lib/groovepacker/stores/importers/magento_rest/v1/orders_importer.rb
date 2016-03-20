module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        module V1
          class OrdersImporter < Groovepacker::Stores::Importers::Importer
            
            def import
              handler = self.get_handler
              credential = handler[:credential]
              client = handler[:store_handle][:handle]
              import_item = handler[:import_item]
              result = self.build_result
              import_time = DateTime.now

              begin
                orders = client.orders
                if orders.present? && orders["messages"].blank?
                  result[:total_imported] = orders.length
                  import_item.current_increment_id = ''
                  import_item.success_imported = 0
                  import_item.previous_imported = 0
                  import_item.current_order_items = -1
                  import_item.current_order_imported_item = -1
                  import_item.to_import = result[:total_imported]
                  import_item.save

                  orders.each do |order|
                    import_item.reload
                    break if import_item.status == 'cancelled'
                    order = order.last
                    import_item.current_increment_id = order["increment_id"]
                    import_item.current_order_items = -1
                    import_item.current_order_imported_item = -1
                    import_item.save

                    if Order.where(:increment_id => order["increment_id"]).length == 0
                      @order = Order.new
                      @order.increment_id = order["increment_id"]
                      @order.status = 'awaiting'
                      @order.order_placed_time = order["created_at"].to_datetime
                      @order.store = credential.store
                      line_items = order["order_items"]

                      import_item.current_order_items = line_items.length
                      import_item.current_order_imported_item = 0
                      import_item.save
                      line_items.each do |line_item|
                        product_id=nil
                        @order_item = OrderItem.new
                        @order_item.price = line_item["price"]
                        @order_item.qty = line_item["qty_ordered"]
                        @order_item.row_total= line_item["row_total"]
                        @order_item.name = line_item["name"]
                        @order_item.sku = line_item["sku"]

                        product_sku = ProductSku.find_by_sku(line_item["sku"])
                        #if line_item_product["type_id"] == 'simple'
                          if product_sku.blank?
                            filters = {
                              "filter%5B0%5D%5Battribute%5D" => "sku",
                              "filter%5B0%5D%5Bin%5D%5B0%5D" => line_item["sku"]
                            }
                            line_item_product = client.order_item_product(filters).first.last rescue {}
                            product_id = Groovepacker::Stores::Importers::MagentoRest::
                            ProductsImporter.new(handler).import_single(line_item_product)
                          else
                          	product_id = product_sku.product_id
                          end
                        #else
                        #  if product_sku.blank?
                        #  	product_id = Groovepacker::Stores::Importers::MagentoRest::ProductsImporter.new(handler).import_single(line_item_product)
                        #  end
                        #end
                        @order_item.product_id = product_id
                        @order.order_items << @order_item
                        import_item.current_order_imported_item = import_item.current_order_imported_item + 1
                        import_item.save
                      end

                      #if product does not exist import product using product.info
                      (order["addresses"]||[]).each do |address|
                      	next unless address["address_type"]=="billing"
                        street_address = address["street"].split("\n") rescue []
                        @order.address_1 = street_address[0]
                        @order.address_2 = street_address[1]
                      	@order.city = address["city"]
                      	@order.country = address["country_id"]
                      	@order.postcode = address["postcode"]
                      	@order.email = address["email"]
                      	@order.lastname = address["lastname"]
                      	@order.firstname = address["firstname"]
                      	@order.state = address["region"]
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
                        import_item.success_imported = result[:success_imported]
                        import_item.save
                      end
                    else
                      result[:previous_imported] = result[:previous_imported] + 1
                      import_item.previous_imported = result[:previous_imported]
                      import_item.save
                    end
                  end
                else
                  response_error = orders["messages"]["error"].first rescue nil
                  if response_error
                    result[:status] &= false
                    result[:messages].push(response_error["message"])
                    import_item.status="failed"
                    import_item.message = response_error["message"]
                    import_item.save
                  end
                end
              rescue Exception => e
                result[:status] &= false
                result[:messages].push(e.message)
                import_item.status = "failed"
                import_item.message = e.message
                import_item.save
              end
              import_item.reload
              if import_item.status != 'cancelled' and import_item.status!="failed"
              	credential.last_imported_at = import_time
              	credential.save
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
end
