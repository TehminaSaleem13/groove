module Groovepacker
  module Dashboard
    module Stats
      class AnalyticStatStream
        def initialize
          
        end

        def stream_detail(tenant_name)
          begin
            stat_stream = []
            Apartment::Tenant.switch(tenant_name)
            
            orders = Order.where(status: 'scanned')
            return if orders.empty?
            orders.each do |order|
              # result = build_result
              # exception = order.order_exception
              # users = User.where(id: order.packing_user_id)
              # next if users.empty?
              # user = users.first
              # result[:order_increment_id] = order.increment_id
              # result[:item_count] = order.order_items.count
              # result[:scanned_on] = order.scanned_on
              # result[:packing_user_id] = order.packing_user_id
              # result[:packing_user_name] = user.username
              # result[:inaccurate_scan_count] = order.inaccurate_scan_count
              # result[:packing_time] = order.total_scan_time
              # result[:scanned_item_count] = order.total_scan_count
              # if exception
              #   result[:exception_description] = exception.description
              #   result[:exception_reason] = exception.reason
              # end
              result = build_stream(order)
              stat_stream.push(result)
            end
          rescue Exception => e
            puts e.message
          end
          stat_stream
        end

        def build_stream(order)
          result = {}
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

        # def build_result
        #   {
        #     order_increment_id: '',
        #     item_count: 0,
        #     scanned_on: nil,
        #     packing_user_id: 0,
        #     packing_user_name: '',
        #     inaccurate_scan_count: 0,
        #     packing_time: 0,
        #     scanned_item_count: 0,
        #     exception_description: nil,
        #     exception_reason: nil
        #   }
        # end
      end
    end
  end
end
