# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Amazon
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import
            init_common_objects
            begin
              @orders = []
              first_call = true
              response = {}
              loop do
                begin
                  if first_call
                    first_call = false
                    last_imported_at = @credential.last_imported_at
                    if last_imported_at.present? && @import_item.import_type == 'regular'
                      days_count = (DateTime.now.in_time_zone.to_date - @credential.last_imported_at.to_date).to_i
                      days_count = days_count == 0 ? 1 : days_count
                    elsif @import_item.import_type == 'deep'
                      days_count = @import_item.days
                    else
                      days_count = 5
                    end
                    if @credential.shipped_status
                      shipped_response = @mws.orders.list_orders last_updated_after: days_count.days.ago,
                                                                 order_status: ['Shipped']
                    end
                    if @credential.unshipped_status
                      unshipped_response = @mws.orders.list_orders last_updated_after: days_count.days.ago,
                                                                   order_status: %w[
                                                                     Unshipped PartiallyShipped
                                                                   ]
                    end
                    if @credential.shipped_status && @credential.unshipped_status
                      response['orders'] = shipped_response.orders.push(unshipped_response.orders).flatten
                    elsif shipped_response.present?
                      response = shipped_response
                    else
                      response = unshipped_response
                    end
                  else
                    loop do
                      response = @mws.orders.next
                      break
                    rescue StandardError
                      response = @mws.orders.next
                    end
                  end
                rescue StandardError
                  response
                end
                orders_count = begin
                  response['orders'].try(:count)
                rescue StandardError
                  0
                end
                grouped_response = begin
                  response['orders'].group_by { |d| d['fulfillment_channel'] }
                rescue StandardError
                  {}
                end
                if !@credential.afn_fulfillment_channel && !@credential.mfn_fulfillment_channel
                  response = {}
                elsif @credential.afn_fulfillment_channel && !@credential.mfn_fulfillment_channel
                  response['orders'] = grouped_response['AFN']
                elsif @credential.mfn_fulfillment_channel && !@credential.afn_fulfillment_channel
                  response['orders'] = grouped_response['MFN']
                end
                response['orders'].is_a?(Array) && !response['orders'].nil? ? (@orders || []).push(response['orders']) : @orders = response['orders']
                break if orders_count.to_i < 100
              end
              @orders = begin
                @orders.flatten
              rescue StandardError
                []
              end
              @result[:total_imported] = begin
                @orders.count
              rescue StandardError
                0
              end
              check_orders
            rescue Exception => e
              @result[:status] &= false
              @result[:messages].push(e.message)
              @import_item.message = e.message
              @import_item.save
            end
            if @result[:status]
              @credential.last_imported_at = DateTime.now.in_time_zone
              @credential.save
            end
            update_orders_status
            @result
          end

          def check_orders
            return if @orders.nil?

            initialize_import_item
            orders_import
          end

          def orders_import
            @orders.each do |order|
              import_item_fix
              break if @import_item.status == 'cancelled' || @import_item.status.nil?

              @import_item.update(current_increment_id: order.amazon_order_id, current_order_items: -1,
                                  current_order_imported_item: -1)
              orders_with_increment_id(order)
            end
          end

          def orders_with_increment_id(order)
            if Order.where(increment_id: order.amazon_order_id).empty?
              create_order_and_update_import_item(order)
              grouped_item_sku
              check_shipping_order(order)
              order_save
              sleep 5 unless Rails.env.test?
            else
              import_item_save
            end
          end

          def create_order_and_update_import_item(order)
            @order = Order.new(status: 'awaiting', increment_id: order.amazon_order_id,
                               order_placed_time: order.purchase_date, store: @credential.store)
            @order_items = @mws.orders.list_order_items amazon_order_id: order.amazon_order_id
            @import_item.update(current_order_items: @order_items.length, current_order_imported_item: 0)
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
              if item.item_price.amount.present? && item.quantity_ordered.present?
                @order_item.row_total = item.item_price.amount.to_i * item.quantity_ordered.to_i
              end
            end
            @order_item.assign_attributes(qty: item.quantity_ordered, sku: item.seller_sku)
          end

          def create_productsku_order_item(item)
            if ProductSku.where(sku: item.seller_sku).empty?
              create_product_and_product_sku(item)
              Groovepacker::Stores::Importers::Amazon::ProductsImporter.new(handler).import_single(
                product_sku: item.seller_sku, product_id: @product.id, handler:
              )
              @order_item.product = @product
            else
              @order_item.product = ProductSku.where(sku: item.seller_sku).first.product
            end
          end

          def create_product_and_product_sku(item)
            @product = Product.new(name: 'New imported item', store_product_id: 0, store: @credential.store)
            @product.product_skus.build(sku: item.seller_sku)
            @product.save
          end

          def update_import_item(_item)
            @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
            @import_item.save
          end

          def check_shipping_order(order)
            return if order.shipping_address.nil?

            split_name = order.shipping_address.name.to_s.split(' ')
            @order.assign_attributes(address_1: order.shipping_address.address_line1,
                                     city: order.shipping_address.city, country: order.shipping_address.country_code, postcode: order.shipping_address.postal_code, state: order.shipping_address.state_or_region, email: order.buyer_email, lastname: split_name.pop, firstname: split_name.join(' '))
          end

          def order_save
            return unless @order.save

            # order_add_new_item
            order_add_activity
            @order.set_order_status
            @result[:success_imported] = @result[:success_imported] + 1
            @import_item.success_imported = @result[:success_imported]
            @import_item.save
          end

          # def order_add_new_item
          #   if !@order.addnewitems
          #     @result[:status] &= false
          #     @result[:messages].push('Problem adding new items')
          #   end
          # end

          def order_add_activity
            @order.addactivity('Order Import', "#{@credential.store.name} Import")
            @order.order_items.each do |item|
              if item.qty.blank? || item.qty < 1
                @order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:",
                                   "#{@credential.store.name} Import")
                item.destroy
                next
              end
              if item.product.present? || item.product.primary_sku.present?
                @order.addactivity("Item with SKU: #{item.sku} Added",
                                   "#{@credential.store.name} Import")
              end
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
