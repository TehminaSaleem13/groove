module Groovepacker
  module Stores
    module Importers
      module Teapplix
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            init_common_objects
            response = @client.orders(@import_item)
            last_imported_date = Time.now
            
            @result[:total_imported] = response["orders"].nil? ? 0 : response["orders"].length
            @import_item.update_attributes(:current_increment_id => '', :success_imported => 0, :previous_imported => 0, :current_order_items => -1, :current_order_imported_item => -1, :to_import => @result[:total_imported])
            (response["orders"]||[]).each do |order|
              @import_item.reload
              break if @import_item.status == 'cancelled'
              @import_item.update_attributes(:current_increment_id => order[:txn_id], :current_order_items => -1, :current_order_imported_item => -1)
              import_single_order(order)
            end
            @credential.update_attributes( :last_imported_at => last_imported_date ) if @import_item.status != 'cancelled'
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
            teapplix_order = Order.new(store_id: @credential.store_id)
            teapplix_order = import_order(teapplix_order, order)

            #import items in an order
            teapplix_order = import_order_items(teapplix_order, order)
            teapplix_order.save
            teapplix_order.reload
            #Pull inventory for the order products
            #pull_inventory_for(teapplix_order)
            #Setting order status
            teapplix_order.set_order_status
            #add order activities
            add_order_activities(teapplix_order)
            #increase successful import count with 1 and save
            update_success_import_count
          end

          def import_order(teapplix_order, order)
            teapplix_order.increment_id = order[:txn_id]
            teapplix_order.store_order_id = order[:txn_id]
            teapplix_order.order_placed_time = order[:date].try(:to_datetime)
            #add order shipping address using separate method
            teapplix_order = add_customer_info(teapplix_order, order)
            #add order shipping address using separate method
            teapplix_order = add_order_shipping_address(teapplix_order, order)
            
            #teapplix_order.customer_comments = order["customer_message"]
            teapplix_order.qty = order[:num_order_lines]
            return teapplix_order
          end

          def import_order_items(teapplix_order, order)
            return teapplix_order if order[:items].nil?
            
            #order["products"] = @client.order_products(order["products"]["url"])
            @import_item.update_attributes(:current_order_items => order[:items].length, :current_order_imported_item => 0 )

            (order[:items]||[]).each do |item|
              order_item = OrderItem.new
              import_order_item(order_item, item)
              @import_item.current_order_imported_item += 1
              @import_item.save
              #second parameter in below method call is to tell weather to import inv or not
              product = teapplix_context.import_teapplix_single_product(item)
              order_item.product = product rescue nil
              teapplix_order.order_items << order_item
            end
            teapplix_order.save
            return teapplix_order
          end

          def import_order_item(order_item, line_item)
            order_item.sku = line_item[:item_sku]
            order_item.name = line_item[:item_name]
            order_item.qty = line_item[:quantity]
            order_item.price = line_item[:subtotal].to_f / line_item[:quantity].to_i
            order_item.row_total = line_item[:subtotal].to_f *
              line_item[:quantity].to_f
            order_item
          end

          def add_customer_info(teapplix_order, order)
            teapplix_order.email = order[:payer_email]
            customer_name = get_firstname_lastname(order[:name])
            teapplix_order.firstname = customer_name[1]
            teapplix_order.lastname = customer_name[0]
            return teapplix_order
          end
          
          def get_firstname_lastname(customer_name)
						name_array = customer_name.to_s.split(" ")
						last_name = name_array.last.to_s
						first_name = (name_array-[last_name]).join(" ")
						name_array = [first_name, last_name]
						return name_array
					end

          def add_order_shipping_address(teapplix_order, order)
            teapplix_order.address_1 = order[:address_street]
            teapplix_order.address_2 = order[:address_street2]
            teapplix_order.city = order[:address_city]
            teapplix_order.state = order[:address_state]
            teapplix_order.postcode = order[:address_zip]
            teapplix_order.country = order[:address_country]
            return teapplix_order
          end

          def teapplix_context
            handler = Groovepacker::Stores::Handlers::TeapplixHandler.new(@credential.store)
            context = Groovepacker::Stores::Context.new(handler)
            return context
          end

          def pull_inventory_for(teapplix_order)
            teapplix_order.order_items.each do |item|
              bc_context.pull_single_product_inventory(item.product)
            end
          end

          def add_order_activities(teapplix_order)
            teapplix_order.addactivity("Order Import", @credential.store.name+" Import")
            teapplix_order.order_items.each do |item|
              primary_sku = item.product.primary_sku rescue nil
              next if primary_sku.nil?
              teapplix_order.addactivity("Item with SKU: "+primary_sku+" Added", @credential.store.name+" Import")
            end
          end

          def update_success_import_count
            @import_item.success_imported += 1
            @import_item.save
            @result[:success_imported] += 1
          end

          def delete_order_if_exists(order)
            existing_order = Order.find_by_increment_id(order[:txn_id])
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
