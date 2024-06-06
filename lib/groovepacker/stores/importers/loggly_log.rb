module Groovepacker
  module Stores
    module Importers
      class LogglyLog
        class << self
          def log_orders_response(orders, store, import_item, shipments_response = nil)
            @store = store
            @import_item = import_item
            data = log_data(orders, shipments_response)
            Groovepacker::LogglyLogger.log(Apartment::Tenant.current, log_type, data)
          end

          private

          def log_data(orders, shipments_response)
            data = {
                      store: @store,
                      import_item: @import_item,
                      orders_respone: order_log_attributes(orders, shipments_response)
                    }
            data
          end

          def order_log_attributes(orders, shipments_response = nil)
            if @store.store_type == 'Shipstation API 2'
              attributes_for_shipstation(orders, shipments_response)
            elsif @store.store_type == 'Shopify'
              attributes_for_shopify(orders)
            elsif @store.store_type == 'ShippingEasy'
              attributes_for_shiping_easy(orders)
            elsif @store.store_type == 'Veeqo'
              attributes_for_veeqo(orders)
            else
              []
            end
          end

          def attributes_for_veeqo(orders)
            orders.map do |order|
              tracking_number = order&.dig('allocations', 0, 'shipment', 'tracking_number', 'tracking_number')
              shipping_address = order&.dig('customer', 'shipping_addresses', 0)
              
              {
                order_number: order['number'],
                status: order['status'],
                store_order_id: order['id'].to_s,
                order_placed_time: order['created_at'],
                last_modified: order['updated_at'],
                tracking_num: tracking_number,
                customer_details: {
                  email: order.dig('customer', 'email'),
                  first_name: shipping_address.dig('first_name'),
                  last_name: shipping_address.dig('last_name'),
                  address1: shipping_address.dig('address1'),
                  address2: shipping_address.dig('address2'),
                  city: shipping_address.dig('city'),
                  state: shipping_address.dig('state'),
                  zip: shipping_address.dig('zip'),
                  country: shipping_address.dig('country')
                },
                customer_comments: order.dig('customer_note', 'text'),
                line_items: veeqo_line_items(order['line_items'])
              }
            end
          end

          def veeqo_line_items(line_items)
            line_items.map do |item|
              sellable = item['sellable']
              {
                product_title: sellable['full_title'],
                sku: sellable['sku_code'],
                barcode: sellable['upc_code'],
                image_url: sellable['image_url'],
                quantity_on_hand: sellable.dig('inventory', 'physical_stock_level_at_all_warehouses')
              }
            end
          end

          def attributes_for_shipstation(orders, shipments_response)
            orders.map do |order|
              tracking_number = (shipments_response || []).find { |shipment| shipment['orderId'] == order['orderId'] && shipment['voided'] == false }&.dig('trackingNumber') || {}
              
              {
                order_number: order['orderNumber'],
                status: order['orderStatus'],
                store_order_id: order['orderId'].to_s,
                order_placed_time: order['orderDate'],
                last_modified: order['modifyDate'],
                tracking_num: tracking_number,
                shipping_amount: order['shippingAmount'],
                order_total: order['amountPaid'],
                ss_label_data: order&.slice('orderId', 'carrierCode', 'serviceCode', 'packageCode', 'confirmation', 'shipDate', 'weight', 'dimensions', 'insuranceOptions', 'internationalOptions', 'advancedOptions'),
                customer_details: {
                  email: order['customerEmail'],
                  full_name: order.dig('shipTo', 'name'),
                  address1: order.dig('shipTo', 'street1'),
                  address2: order.dig('shipTo', 'street2'),
                  city: order.dig('shipTo', 'city'),
                  state: order.dig('shipTo', 'state'),
                  zip: order.dig('shipTo', 'postalCode'),
                  country: order.dig('shipTo', 'country')
                },
                notes_internal: order['internalNotes'],
                customer_comments: order['customerNotes'],
                line_items: ss_line_items(order['items'])
              }
            end
          end

          def ss_line_items(items)
            items.map do |item|
              {
                product_title: item['name'],
                store_product_id: item['productId'],
                sku: item['sku'],
                barcode: item['upc'],
                image_url: item['imageUrl'],
                warehouseLocation: item['warehouseLocation'],
              }
            end
          end

          def attributes_for_shopify(orders)
            orders.map do |order|
              tracking_number = (order['fulfillments'] || []).find { |f| f['tracking_number'].present? }&.dig('tracking_number')
              
              {
                order_number: order['name'],
                status: order['fulfillment_status'],
                store_order_id: order['id'].to_s,
                order_placed_time: order['created_at'],
                last_modified: order['updated_at'],
                tracking_num: tracking_number,
                tags: order['tags'],
                customer_details: {
                  email: order.dig('customer', 'email'),
                  first_name: order.dig('shipping_address', 'first_name'),
                  last_name: order.dig('shipping_address', 'last_name'),
                  address1: order.dig('shipping_address', 'address1'),
                  address2: order.dig('shipping_address', 'address2'),
                  city: order.dig('shipping_address', 'city'),
                  state: order.dig('shipping_address', 'state'),
                  zip: order.dig('shipping_address', 'zip'),
                  country: order.dig('shipping_address', 'country')
                },
                customer_comments: order['note'],
                line_items: shopify_line_items(order['line_items'])
              }
            end
          end

          def shopify_line_items(line_items)
            line_items.map do |item|
              {
                product_title: item['name'],
                sku: item['sku'],
                store_product_id: item['variant_id']
              }
            end
          end

          def attributes_for_shiping_easy(orders)
            orders.map do |order|
              ship_addr = order.dig('recipients', 0)
              tracking_number = order['shipments']&.find { |shipment| shipment['tracking_number'].present? }&.dig('tracking_number')
              
              {
                order_number: order['external_order_identifier'],
                status: order['order_status'],
                order_placed_time: order['ordered_at'],
                last_modified: order['updated_at'],
                tracking_num: tracking_number,
                shipping_amount: order['base_shipping_cost'],
                order_total: order['total_excluding_tax'],
                notes_internal: order['internal_notes'],
                weight_oz: order.dig('recipients', 0, 'original_order', 'total_weight_in_ounces'),
                custom_field_one: order.dig('recipients', 0, 'original_order', 'custom_1'),
                custom_field_two: order.dig('recipients', 0, 'original_order', 'custom_2'),
                customer_comments: order['notes'],
                origin_store_id: order.dig('recipients')&.first.dig('original_order','store_id'),
                prime_order_id: order['prime_order_id'],
                source_order_ids: order['source_order_ids'].to_a.join(','),
                split_from_order_id: order['split_from_order_id'],
                customer_details: {
                  email: order['billing_email'],
                  first_name: ship_addr['first_name'],
                  last_name: ship_addr['last_name'],
                  address1: ship_addr['address'],
                  address2: ship_addr['address2'],
                  city: ship_addr['city'],
                  state: ship_addr['state'],
                  zip: ship_addr['postal_code'],
                  country: ship_addr['country']
                },
                line_items: se_line_items(order['recipients'][0]['line_items'])
              }
            end
          end

          def se_line_items(line_items)
            line_items.map do |item|
              {
                product_title: item['item_name'],
                store_product_id: item['ext_line_item_id'],
                sku: item['sku'],
                barcode: item.dig('product', 'upc'),
                image_url: item.dig('product', 'image', 'original')
              }
            end
          end

          def store_name
            @store&.store_type&.downcase&.gsub(/\s/, '_')
          end

          def log_type
            "#{store_name}_import-store_id-#{@store.id}"
          end
        end
      end
    end
  end
end
