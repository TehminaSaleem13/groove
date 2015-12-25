module Groovepacker
  module Stores
    module Importers
      module BigCommerce
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            init_common_objects
            response = @client.orders(@credential, @import_item)
            last_imported_date = Time.now
            
            @result[:total_imported] = response["orders"].nil? ? 0 : response["orders"].length
            @import_item.update_attributes(:current_increment_id => '', :success_imported => 0, :previous_imported => 0, :current_order_items => -1, :current_order_imported_item => -1, :to_import => @result[:total_imported])

            (response["orders"]||[]).each do |order|
              @import_item.update_attributes(:current_increment_id => order["id"], :current_order_items => -1, :current_order_imported_item => -1)
              import_single_order(order)
            end
            @credential.update_attributes( :last_imported_at => last_imported_date )
            
            @result
          end

          private
          def init_common_objects
            handler = self.get_handler
            @credential = handler[:credential]
            @client = handler[:store_handle]
            @import_item = handler[:import_item]
            @result = self.build_result
          end

          def import_single_order(order)
            #Delete if order exists and is not scanned so modified order can be saved with new changes
            return unless delete_order_if_exists(order)

            #create new order
            bigcommerce_order = Order.new(store_id: @credential.store.id)
            import_order(bigcommerce_order, order)

            #import items in an order
            bigcommerce_order = import_order_items(bigcommerce_order, order)
            #Pull inventory for the order products
            pull_inventory_for(bigcommerce_order)
            #Setting order status
            bigcommerce_order.set_order_status
            #add order activities
            add_order_activities(bigcommerce_order)
            #increase successful import count with 1 and save
            update_success_import_count
          end

          def import_order(bigcommerce_order, order)
            bigcommerce_order.increment_id = order["id"]
            bigcommerce_order.store_order_id = order["id"].to_s
            bigcommerce_order.order_placed_time = order["date_created"].to_datetime
            #add order shipping address using separate method
            bigcommerce_order = add_customer_info(bigcommerce_order, order)
            #add order shipping address using separate method
            bigcommerce_order = add_order_shipping_address(bigcommerce_order, order)
            
            bigcommerce_order.customer_comments = order["customer_message"]
            bigcommerce_order.qty = order["items_total"]
          end

          def import_order_items(bigcommerce_order, order)
            return if order["products"].nil?
            
            order["products"] = @client.order_products(order["products"]["url"])
            @import_item.update_attributes(:current_order_items => order["products"].length, :current_order_imported_item => 0 )

            (order["products"]||[]).each do |item|
              order_item = OrderItem.new
              import_order_item(order_item, item)
              @import_item.current_order_imported_item += 1
              @import_item.save

              #second parameter in below method call is to tell weather to import inv or not
              product = bc_context.import_bc_single_product(item, false)
              
              order_item.product = product
              bigcommerce_order.order_items << order_item
            end
            bigcommerce_order.save
            return bigcommerce_order
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

          def add_customer_info(bigcommerce_order, order)
            return bigcommerce_order if order["customer_id"].nil?
            order["customer"] = @client.customer("https://api.bigcommerce.com/#{@client.as_json["store_hash"]}/v2/customers/#{order["customer_id"]}")
            bigcommerce_order.email = order["customer"]["email"]
            bigcommerce_order.lastname = order["customer"]["last_name"]
            bigcommerce_order.firstname = order["customer"]["first_name"]
            return bigcommerce_order
          end

          def add_order_shipping_address(bigcommerce_order, order)
            return bigcommerce_order if order["shipping_addresses"].nil?
            shipping_addresses = @client.shipping_addresses(order["shipping_addresses"]["url"])
            shipping_address = shipping_addresses.first
            bigcommerce_order.address_1 = shipping_address["street_1"]
            bigcommerce_order.address_2 = shipping_address["street_2"]
            bigcommerce_order.city = shipping_address["city"]
            bigcommerce_order.state = shipping_address["state"]
            bigcommerce_order.postcode = shipping_address["zip"]
            bigcommerce_order.country = shipping_address["country"]
            return bigcommerce_order
          end

          def bc_context
            handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(@credential.store)
            context = Groovepacker::Stores::Context.new(handler)
            return context
          end

          def pull_inventory_for(bigcommerce_order)
            bigcommerce_order.order_items.each do |item|
              bc_context.pull_single_product_inventory(item.product)
            end
          end

          def add_order_activities(bigcommerce_order)
            bigcommerce_order.addactivity("Order Import", @credential.store.name+" Import")
            bigcommerce_order.order_items.each do |item|
              primary_sku = item.product.primary_sku rescue nil
              next if primary_sku.nil?
              bigcommerce_order.addactivity("Item with SKU: "+primary_sku+" Added", @credential.store.name+" Import")
            end
          end

          def update_success_import_count
            @import_item.success_imported += 1
            @import_item.save
            @result[:success_imported] += 1
          end

          def delete_order_if_exists(order)
            existing_order = Order.find_by_increment_id(order["id"])
            if existing_order && existing_order.status!="scanned"
              existing_order.destroy
              return true
            else
              return_val = existing_order ? false : true
              return return_val
            end
          end

        end
      end
    end
  end
end
