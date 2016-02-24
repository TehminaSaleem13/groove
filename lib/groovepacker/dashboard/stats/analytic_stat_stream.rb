module Groovepacker
  module Dashboard
    module Stats
      class AnalyticStatStream
        def initialize
          
        end

        def stream_detail(tenant_name, trace_untraced = false)
          begin
            stat_stream = []
            Apartment::Tenant.switch(tenant_name)
            puts "switched tenant."
            orders = get_list(trace_untraced)
            puts "found all orders with scanned status"
            return stat_stream if orders.empty?
            puts "iterate over the orders"
            orders.each do |order|
              if !order.increment_id.nil? && !order.scanned_on.nil?
                result = build_stream(order.id)
                stat_stream.push(result)
              end
            end
          rescue Exception => e
            puts e.message
          end
          stat_stream
        end

        def build_stream(order_id)
          result = build_result
          order = Order.find(order_id)
          exception = order.order_exception
          users = User.where(id: order.packing_user_id)
          unless users.empty?
            user = users.first
            result[:order_increment_id] = order.increment_id
            result[:item_count] = order.order_items.count
            result[:scanned_on] = order.scanned_on
            result[:packing_user_id] = order.packing_user_id
            result[:packing_user_name] = user.username
            result[:inaccurate_scan_count] = order.inaccurate_scan_count
            result[:packing_time] = order.total_scan_time
            result[:scanned_item_count] = order.total_scan_count
            if exception
              result[:exception_description] = exception.description
              result[:exception_reason] = exception.reason
            end
          end
          result
        end

        def get_list(trace_untraced)
          return Order.where(status: 'scanned').where(traced_in_dashboard: false) if trace_untraced
          Order.where(status: 'scanned')
        end

        def get_order_stream(tenant, order_id)
          Apartment::Tenant.switch(tenant)
          build_stream(order_id)
        end

        def build_result
          {
            order_increment_id: '',
            item_count: 0,
            scanned_on: nil,
            packing_user_id: 0,
            packing_user_name: '',
            inaccurate_scan_count: 0,
            packing_time: 0,
            scanned_item_count: 0,
            exception_description: nil,
            exception_reason: nil
          }
        end
      end
    end
  end
end
