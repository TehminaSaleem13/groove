module Groovepacker
  module Stores
    module Importers
      module Amazon
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import
            init_common_objects
            begin
              @orders = []
              first_call=true
              
              while 1 do
                if first_call
                  first_call = false
                  response = @mws.orders.list_orders :last_updated_after => 7.days.ago, :order_status => ['Unshipped', 'PartiallyShipped']
                else
                  response = @mws.orders.next
                end
                response.orders.kind_of?(Array) && !response.orders.nil? ? @orders.push(response.orders) : @orders = response.orders
                break if response["orders"].try(:count).to_i < 100 
              end
              @orders = @orders.flatten rescue []
              @result[:total_imported] = @orders.count rescue 0
              check_orders
            rescue Exception => e
              @result[:status] &= false
              @result[:messages].push(e.message)
              @import_item.message = e.message
              @import_item.save
            end
            update_orders_status
            @result
          end

          def check_orders
            if !@orders.nil?
              initialize_import_item
              orders_import
            end
          end

          def orders_import
            @orders.each do |order|
              @import_item.reload
              break if @import_item.status == 'cancelled'
              @import_item.update_attributes(current_increment_id: order.amazon_order_id, current_order_items: -1, current_order_imported_item: -1 )
              orders_with_increment_id(order)
              sleep 0.2
            end
          end

          def orders_with_increment_id(order)
            if Order.where(:increment_id => order.amazon_order_id).length == 0
              create_order_and_update_import_item(order)
              grouped_item_sku
              check_shipping_order(order)
              order_save
            else
              import_item_save
            end
          end

          def create_order_and_update_import_item(order)
            @order = Order.new(status: 'awaiting',increment_id: order.amazon_order_id, order_placed_time: order.purchase_date, store: @credential.store)
            @order_items = @mws.orders.list_order_items :amazon_order_id => order.amazon_order_id
            @import_item.update_attributes(current_order_items: @order_items.length, current_order_imported_item: 0)
          end

          def grouped_item_sku
            @order_items.order_items.each do |item|
              create_order_item(item)
              create_productsku_order_item(item)
              @order_item.name = item.title
              update_import_item(item)   
            end
          end

          def create_order_item(item)
            @order_item = @order.order_items.build
            unless item.item_price.nil?
              @order_item.assign_attributes(price: item.item_price.amount.to_i)
              @order_item.row_total= item.item_price.amount.to_i * item.quantity_ordered.to_i if item.item_price.amount.present? && item.quantity_ordered.present?
            end
            @order_item.assign_attributes(qty: item.quantity_ordered, sku: item.seller_sku)
          end

          def create_productsku_order_item(item)
            if ProductSku.where(:sku => item.seller_sku).length == 0
              create_product_and_product_sku(item)
              Groovepacker::Stores::Importers::Amazon::ProductsImporter.new(handler).import_single({ product_sku: item.seller_sku, product_id: @product.id, handler: handler })
              @order_item.product = @product
            else
              @order_item.product = ProductSku.where(:sku => item.seller_sku).first.product
            end
          end

          def create_product_and_product_sku(item)
            @product = Product.new(name: 'New imported item', store_product_id: 0, store: @credential.store)
            @product.product_skus.build(sku: item.seller_sku)
            @product.save
          end

          def update_import_item(item)
            @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
            @import_item.save
          end

          def check_shipping_order(order)
            unless order.shipping_address.nil?
              split_name = order.shipping_address.name.split(' ')
              @order.assign_attributes(address_1: order.shipping_address.address_line1, city: order.shipping_address.city, country: order.shipping_address.country_code, postcode: order.shipping_address.postal_code, state: order.shipping_address.state_or_region, email: order.buyer_email, lastname: split_name.pop, firstname: split_name.join(' '))
            end
          end

          def order_save
            if @order.save
              # order_add_new_item
              order_add_activity
              @order.set_order_status
              @result[:success_imported] = @result[:success_imported] + 1
              @import_item.success_imported = @result[:success_imported]
              @import_item.save
            end
          end

          # def order_add_new_item
          #   if !@order.addnewitems
          #     @result[:status] &= false
          #     @result[:messages].push('Problem adding new items')
          #   end
          # end

          def order_add_activity
            @order.addactivity("Order Import", "#{@credential.store.name} Import")
            @order.order_items.each do |item|
              if item.qty.blank? || item.qty<1
                @order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:", "#{@credential.store.name} Import")
                item.destroy
                next
              end
              @order.addactivity("Item with SKU: #{item.sku} Added", "#{@credential.store.name} Import") if item.product.present? || item.product.primary_sku.present? 
            end
          end

          def import_item_save
            @result[:previous_imported] = @result[:previous_imported] + 1
            @import_item.previous_imported = @result[:previous_imported]
            @import_item.save 
          end   
        end
      end
    end
  end
end