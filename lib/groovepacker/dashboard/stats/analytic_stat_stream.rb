# frozen_string_literal: true

module Groovepacker
  module Dashboard
    module Stats
      class AnalyticStatStream
        def initialize; end

        def stream_detail(tenant_name, trace_untraced = false)
          begin
            stat_stream = []
            Apartment::Tenant.switch!(tenant_name)
            puts 'switched tenant.'
            orders = get_list(trace_untraced)
            puts 'found all orders with scanned status'
            return stat_stream if orders.empty?

            puts 'iterate over the orders'
            orders.each do |order|
              if order.increment_id
                result = build_stream(order)
                stat_stream.push(result) unless result.empty?
              end
            end
          rescue Exception => e
            puts e.message
          end
          stat_stream
        end

        def build_stream(order)
          result = build_result
          @user = order.packing_user
          # uncomment the following line when is_deleted field is added to users table.
          # return result if @user && @user.is_deleted
          result[:packing_user_name] = if @user && !@user.is_deleted
                                         @user.username
                                       else
                                         'deleted_user'
                                       end
          bind_order_data(order, result)
          bind_exception(order, result)
          result
        end

        def bind_order_data(order, result)
          result[:packing_user_id] = order.packing_user_id ||= 420
          if Order.where(increment_id: order.increment_id).count >= 2
            increment_id = "#{order.increment_id}-#{order.store_order_id}"
            result[:order_increment_id] = increment_id
          else
            result[:order_increment_id] = order.increment_id
          end
          scanned_order_items_without_kit = order.order_items.joins(:product).where(products: { is_intangible: false, is_kit: 0 })
          scanned_order_item_kit_products = OrderItemKitProduct.joins(order_item: :order).where(orders: { id: order.id })
          result[:item_count] = order.order_items.count
          # use updated_at value if scanned_on is nil
          result[:scanned_on] = order.scanned_on ||= order.updated_at
          result[:inaccurate_scan_count] = order.inaccurate_scan_count
          result[:packing_time] = order.total_scan_time
          result[:status] = order.status
          result[:scanned_item_count] = ExportSetting.first.include_partially_scanned_orders_user_stats ? 1 : scanned_order_items_without_kit.map(&:scanned_qty).sum + scanned_order_item_kit_products.map(&:scanned_qty).sum
        end

        def bind_exception(order, result)
          @exception = order.order_exception
          if @exception
            result[:exception_description] = @exception.description
            result[:exception_reason] = @exception.reason
            result[:exception_recorded_date] = @exception.created_at
            result[:exception_assoicated_user] = @exception.user_id
          end
        end

        def get_list(trace_untraced)
          return Order.where('status = ? and traced_in_dashboard = ? and scanned_by_status_change = ?', 'scanned', false, false) if trace_untraced

          Order.where('status = ? and scanned_by_status_change = ?', 'scanned', false)
        end

        def get_order_stream(tenant, order_id)
          Apartment::Tenant.switch!(tenant)
          order = Order.find(order_id)
          build_stream(order)
        end

        def build_result
          {
            order_increment_id: '',
            item_count: 0,
            scanned_on: nil,
            packing_user_id: 0,
            packing_user_name: '',
            inaccurate_scan_count: 0,
            clicked_scanned_qty: 0,
            box_number: 0,
            packing_time: 0,
            scanned_item_count: 0,
            exception_description: nil,
            exception_reason: nil,
            exception_assoicated_user: 0,
            status: ''
          }
        end
      end
    end
  end
end
