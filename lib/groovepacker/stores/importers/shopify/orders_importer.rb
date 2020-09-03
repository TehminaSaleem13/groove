module Groovepacker
  module Stores
    module Importers
      module Shopify
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            initialize_import_objects
            OrderImportSummary.top_summary.emit_data_to_user(true) rescue nil
            response = @client.orders
            @result[:total_imported] = response["orders"].nil? ? 0 : response["orders"].length
            initialize_import_item
            return @result if response["orders"].nil? || response['orders'].blank?
            response['orders'] = response['orders'].sort_by { |h| Time.zone.parse(h['updated_at']) } rescue response['orders']
            response["orders"].each do |order|
              import_item_fix
              break if @import_item.status == 'cancelled'

              import_single_order(order) if order.present?
            end
            @credential.update_attributes(last_imported_at: Time.zone.parse(response['orders'].last['updated_at'])) if @import_item.status != 'cancelled'
            update_orders_status
            @result
          end

          private
            def initialize_import_objects
              handler = self.get_handler
              @credential = handler[:credential]
              @store = @credential.store
              @client = handler[:store_handle]
              @import_item = handler[:import_item]
              @result = self.build_result
            end

            def import_single_order(order)
              @import_item.update_attributes(:current_increment_id => order["id"], :current_order_items => -1, :current_order_imported_item => -1)
              order_in_gp_present = false
              order_in_gp = Order.find_by_increment_id(order["name"])
              if order_in_gp
                order_in_gp_present = true
                is_scanned = order_in_gp && (order_in_gp.status=="scanned" || order_in_gp.status=="cancelled" || order_in_gp.order_items.map(&:scanned_status).include?("partially_scanned") || order_in_gp.order_items.map(&:scanned_status).include?("scanned"))
                #mark previously imported
                update_import_count('success_updated') && return if is_scanned || (order_in_gp.last_modified == Time.zone.parse(order['updated_at']))
                order_in_gp.order_items.destroy_all
              end
              import_order_and_items(order, order_in_gp)
              # #create order
              # shopify_order = Order.new(store: @store)
              # shopify_order = import_order(shopify_order, order)
              # #import items in an order
              # shopify_order = import_order_items(shopify_order, order)
              # #update store
              # shopify_order.set_order_status
              # #add order activities
              # if check_for_replace_product
              #   add_order_activities_for_gp_coupon(shopify_order, order)
              # else
              #   add_order_activities(shopify_order)
              # end
              
              #increase successful import with 1 and save
              order_in_gp_present ? update_import_count('success_updated') : update_import_count('success_imported')
            end

            def import_order(shopify_order, order)
              shopify_order.increment_id = order["name"] 
              shopify_order.store_order_id = order["id"].to_s
              shopify_order.order_placed_time = order["created_at"]
              #add order shipping address using separate method
              shopify_order = add_customer_info(shopify_order, order)
              #add order shipping address using separate method
              shopify_order = add_order_shipping_address(shopify_order, order)
              #update shipping_amount and order weight
              shopify_order = update_shipping_amount_and_weight(shopify_order, order)
              shopify_order.order_total = order["total_price"].to_f unless order["total_price"].nil?
              shopify_order.last_modified = order['updated_at']
              return shopify_order
            end

            def import_order_items(shopify_order, order)
              return if order["line_items"].nil?
              @import_item.current_order_items = order["line_items"].length
              @import_item.current_order_imported_item = 0
              @import_item.save
              order["line_items"] = order["line_items"].reject {|h| h['fulfillment_status'] == nil && h['fulfillable_quantity'] == 0 }
              order["line_items"].each do |item|
                order_item = import_order_item(order_item, item)
                @import_item.update_attributes(:current_order_imported_item => @import_item.current_order_imported_item+1)
                product = shopify_context.import_shopify_single_product(item)
                if product.present?
                  order_item.product = product 
                  shopify_order.order_items << order_item
                end
              end
              shopify_order.save
              return shopify_order
            end

            def import_order_item(order_item, line_item)
              row_total = line_item["price"].to_f * line_item["quantity"].to_f
              order_item = OrderItem.new( :qty => line_item["quantity"],
                                          :price => line_item["price"],
                                          :row_total => row_total )
            end

            def add_customer_info(shopify_order, order)
              return shopify_order if order["customer"].nil?
              shopify_order.email = order["customer"]["email"]
              shopify_order.lastname = order["customer"]["last_name"]
              shopify_order.firstname = order["customer"]["first_name"]
              return shopify_order
            end

            def add_order_shipping_address(shopify_order, order)
              shipping_address = order["shipping_address"]
              return shopify_order if shipping_address.blank?
              shopify_order.address_1 = shipping_address["address1"]
              shopify_order.address_2 = shipping_address["address2"]
              shopify_order.city = shipping_address["city"]
              shopify_order.state = shipping_address["province"]
              shopify_order.postcode = shipping_address["zip"]
              shopify_order.country = shipping_address["country"]
              return shopify_order
            end

            def update_shipping_amount_and_weight(shopify_order, order)
              unless order["shipping_lines"].empty?
                shipping = order["shipping_lines"].first
                shopify_order.shipping_amount = shipping["price"].to_f unless shipping.nil?
              end

              shopify_order.weight_oz = (order["total_weight"].to_i * 0.035274) unless order["total_weight"].nil?
              return shopify_order
            end

            def shopify_context
              handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(@store)
              context = Groovepacker::Stores::Context.new(handler)
              return context
            end

            def update_import_count(import_type = 'success_imported')
              if import_type == 'success_imported'
                @import_item.update_attributes(:success_imported => @import_item.success_imported+1)
                @result[:success_imported] += 1
              else
                @result[:previous_imported] += 1
                @import_item.update_attributes(:updated_orders_import => @import_item.updated_orders_import+1)
              end
            end

            def add_order_activities(shopify_order)
              shopify_order.addactivity("Order Import", @store.name+" Import")
              shopify_order.order_items.each do |item|
                next if item.product.nil? || item.product.primary_sku.nil?
                shopify_order.addactivity("Item with SKU: "+item.product.primary_sku+" Added", @store.name+" Import")
              end
            end

            def add_order_activities_for_gp_coupon(shopify_order, order)
              shopify_order.addactivity("Order Import", @store.name+" Import")
              shopify_order.order_items.each_with_index do |item, index|
                if order["line_items"][index]["name"] == item.product.name &&  order["line_items"][index]["sku"] == item.product.primary_sku
                  next if item.product.nil? || item.product.primary_sku.nil?
                  shopify_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@store.name} Import")
                else
                  intangible_strings = ScanPackSetting.all.first.intangible_string.downcase.strip.split(',')
                  intangible_strings.each do |string|
                    if order["line_items"][index]["name"].downcase.include?(string) || order["line_items"][index]["sku"].downcase.include?(string)
                      shopify_order.addactivity("Intangible item with SKU #{order["line_items"][index]["sku"]}  and Name #{order["line_items"][index]["name"]} was replaced with GP Coupon.","#{@store.name} Import")
                      break
                    end
                  end
                end 
              end  
            end

            def import_order_and_items(order, order_in_gp)
              #create order
              shopify_order = order_in_gp ? order_in_gp : Order.new(store: @store)
              shopify_order = import_order(shopify_order, order)
              #import items in an order
              shopify_order = import_order_items(shopify_order, order)
              #update store
              shopify_order.set_order_status
              #add order activities
              if check_for_replace_product
                add_order_activities_for_gp_coupon(shopify_order, order)
              else
                add_order_activities(shopify_order)
              end
            end
        end
      end
    end
  end
end
