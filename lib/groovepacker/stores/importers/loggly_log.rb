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
                      orders_respone: orders.collect { |order| order.slice(*order_log_attributes) }
                    }
            data.merge!({ shipments: shipments_response }) if shipments_response.present?
            data
          end

          def order_log_attributes
            if @store.store_type == 'Shipstation API 2'
              attributes_for_shipstation
            elsif @store.store_type == 'Shopify'
              attributes_for_shopify
            elsif @store.store_type == 'ShippingEasy'
              attributes_for_shiping_easy
            else
              []
            end
          end

          def attributes_for_shipstation
            %w[orderId
              orderNumber
              orderDate
              customerEmail
              orderStatus
              tagIds
              modifyDate
              shipDate
              internalNotes
              customerNotes
              shipTo
              items
              shippingAmount
              advancedOptions
              amountPaid
              carrierCode
              confirmationattributes_for_shipstation
              dimensions
              insuranceOptions
              internationalOptions
              packageCode
              serviceCode
              weight]
          end

          def attributes_for_shopify
            %w[id name created_at updated_at tags line_items fulfillment_status fulfillments]
          end

          def attributes_for_shiping_easy
            %w[id external_order_identifier order_status ordered_at updated_at shipments recipients]
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
