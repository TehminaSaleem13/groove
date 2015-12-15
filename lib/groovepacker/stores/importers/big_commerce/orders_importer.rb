module Groovepacker
  module Stores
    module Importers
      module BigCommerce
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            import_item = handler[:import_item]
            result = self.build_result
            response = client.orders(credential, import_item)
            orders_product_ids = []
            bc_context = get_bc_context(credential.store)
            
            #========
            credential.update_attributes( :last_imported_at => Time.now )
            result[:total_imported] = response["orders"].nil? ? 0 : response["orders"].length

            import_item.update_attributes(:current_increment_id => '', :success_imported => 0, :previous_imported => 0, :current_order_items => -1, :current_order_imported_item => -1, :to_import => result[:total_imported])

            (response["orders"]||[]).each do |order|
              import_item.update_attributes(:current_increment_id => order["id"], :current_order_items => -1, :current_order_imported_item => -1)
              
              #order = Order.where(increment_id: order["id"])
              if existing_order = Order.find_by_increment_id(order["id"])
                existing_order.destroy
              end

              #create order
              bigcommerce_order = Order.new
              import_order(bigcommerce_order, order, client)

              #import items in an order
              unless order["products"].nil?
                order["products"] = client.order_products(order["products"]["url"])
                import_item.update_attributes(:current_order_items => order["products"].length, :current_order_imported_item => 0 )

                (order["products"]||[]).each do |item|
                  order_item = OrderItem.new
                  import_order_item(order_item, item)
                  import_item.current_order_imported_item += 1
                  import_item.save

                  #second parameter in below method call is to tell weather to import inv or not
                  product = bc_context.import_bc_single_product(item, false)
                  
                  order_item.product = product
                  bigcommerce_order.order_items << order_item
                end
              end

              #update store
              bigcommerce_order.store = credential.store
              bigcommerce_order.save

              bigcommerce_order.order_items.each do |item|
                bc_context.pull_single_product_inventory(item.product)
              end


              bigcommerce_order.set_order_status

              #add order activities
              bigcommerce_order.addactivity("Order Import", credential.store.name+" Import")
              (bigcommerce_order.order_items||[]).each do |item|
                unless item.product.nil? || item.product.primary_sku.nil?
                  bigcommerce_order.addactivity("Item with SKU: "+item.product.primary_sku+" Added", credential.store.name+" Import")
                end
              end

              import_item.success_imported += 1
              import_item.save
              result[:success_imported] += 1
            end

            #========
            result
          end

          def import_order(bigcommerce_order, order, client)
            bigcommerce_order.increment_id = order["id"]
            bigcommerce_order.store_order_id = order["id"].to_s
            bigcommerce_order.order_placed_time = order["date_created"].to_datetime

            unless order["customer_id"].nil?
              order["customer"] = client.customer("https://api.bigcommerce.com/#{client.as_json["store_hash"]}/v2/customers/#{order["customer_id"]}")
              bigcommerce_order.email = order["customer"]["email"]
              bigcommerce_order.lastname = order["customer"]["last_name"]
              bigcommerce_order.firstname = order["customer"]["first_name"]
            end
            
            unless order["shipping_addresses"].nil?
              shipping_addresses = client.shipping_addresses(order["shipping_addresses"]["url"])
              shipping_address = shipping_addresses.first
              bigcommerce_order.address_1 = shipping_address["street_1"]
              bigcommerce_order.address_2 = shipping_address["street_2"]
              bigcommerce_order.city = shipping_address["city"]
              bigcommerce_order.state = shipping_address["state"]
              bigcommerce_order.postcode = shipping_address["zip"]
              bigcommerce_order.country = shipping_address["country"]
            end

            bigcommerce_order.customer_comments = order["customer_message"]
            bigcommerce_order.qty = order["items_total"]

          end

          def import_order_item(order_item, line_item)
            order_item.sku = line_item["sku"]
            order_item.name = line_item["name"]
            order_item.qty = line_item["quantity"]
            order_item.price = line_item["base_price"]
            order_item.row_total = line_item["base_price"].to_f *
              line_item["quantity"].to_f
            order_item
          end

          def get_bc_context(store)
            handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(store)
            context = Groovepacker::Stores::Context.new(handler)
            return context
          end
        end
      end
    end
  end
end
