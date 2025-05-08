# frozen_string_literal: true

module ScanPack
  class OrderAssignmentService
    def initialize(cart, current_user)
      @cart = cart
      @current_user = current_user
      @general_settings = GeneralSetting.setting
      @result = {
        'status' => true,
        'error_messages' => [],
        'success_messages' => [],
        'data' => {
          'assigned_orders' => []
        }
      }
    end

    def assign_orders
      return @result if cart_has_assigned_totes?
      orders = select_orders
      assign_to_totes(orders) if orders.present?
      @result
    end

    def cart_has_assigned_totes?
      if Order.where("assigned_cart_tote_id LIKE ?", "%-%-#{@cart.cart_id}").exists?
        @result['status'] = false
        @result['error_messages'] << 'Cart has totes that are already assigned to orders'
        true
      else
        false
      end
    end

    def assigned_cart_orders_to_current_user
      orders = Order.where("assigned_cart_tote_id LIKE ?", "%-%-#{@cart.cart_id}")
      if orders.exists?
        orders.update_all(assigned_user_id: @current_user.id)
        {
          'status' => true,
          'success_messages' => ['Orders successfully assigned to you'],
          'data' => {}
        }
      else
        {
          'status' => false,
          'error_messages' => ['No orders found for this cart'],
          'data' => {}
        }
      end
    end

    private

    def fetch_priority_oldest_orders
      @counted_order_ids = Order.none
      @priority_cards = PriorityCard.where(is_stand_by: false).order(:position)
      @priority_cards.map do |priority_card|
        unless priority_card.is_user_card && priority_card.is_card_disabled && @counted_order_ids
          priority_card_orders_with_unassigned_user(priority_card.assigned_tag)
        end
      end
      regular_priority_orders
      @counted_order_ids
    end

    def regular_priority_orders
      order_ids = Order.where(status: 'awaiting')
      .where(Order::RECENT_ORDERS_CONDITION, 14.days.ago)
      .where(assigned_user_id: nil)
      .where.not(id: @counted_order_ids.map(&:id)).order(:order_placed_time)
      @counted_order_ids += order_ids
    end

    def priority_card_orders_with_unassigned_user(assigned_tag_name)
      orders_with_tag = Order
      .where(status: 'awaiting', assigned_user_id: nil)
      .where(assigned_cart_tote_id: nil)
      .joins(:order_tags)
      .where(order_tags: { name: assigned_tag_name })
      .where(Order::RECENT_ORDERS_CONDITION, 14.days.ago)
      .where.not(id: @counted_order_ids.map(&:id))
      .group('orders.id')
      .order(:order_placed_time)

      @counted_order_ids += orders_with_tag
    end


    def select_orders
      total_totes = @cart.cart_rows.sum(&:row_count)
      fetch_priority_oldest_orders.first(total_totes)
    end

   def assign_to_totes(orders)
  sorted_items = sort_order_items(orders)
  sorted_orders = sort_orders_by_items(orders, sorted_items)

  sorted_orders.each_with_index do |order, index|
    assign_order_to_tote(order, index + 1)
  end
end

    def sort_order_items(orders)
      items = OrderItem.includes(:product)
                      .where(order_id: orders.pluck(:id))
                      .to_a

      items.sort_by do |item|
        location = get_valid_location(item.product)
        [
          location.blank? ? 0 : 1,
          sort_location_value(location || ''),
          item.product.try(:sku) || ''
        ]
      end
    end

    def sort_location_value(location)
      return [[3, ""]] if location.blank?

      parts = location.to_s.scan(/[^a-zA-Z0-9]|[0-9]+|[a-zA-Z]+/)
      parts.map do |part|
        case part
        when /[^a-zA-Z0-9]/ then [0, part]
        when /[0-9]+/ then [1, part.rjust(10, '0')]
        else [2, part.downcase]
        end
      end
    end

    def get_valid_location(product)
      return nil unless product

      begin
        warehouse = product.product_inventory_warehousess.first
        return nil unless warehouse

        if @general_settings&.inventory_tracking

          location_types = %w[primary secondary tertiary]

          location_types.each do |location_type|
            location = warehouse.send("location_#{location_type}")
            qty = location_type == 'primary' ? warehouse.quantity_on_hand.to_i : warehouse.send("location_#{location_type}_qty").to_i

            if location.present? && qty.positive?
              return location
            end
          end

          return warehouse.location_primary if warehouse.location_primary.present?
        else
          return warehouse.location_primary
        end

        nil
      rescue StandardError => e
        Rails.logger.error("Error getting location for product #{product.id}: #{e.message}")
        nil
      end
    end

    def sort_orders_by_items(orders, sorted_items)
      order_scores = {}

      sorted_items.each_with_index do |item, index|
        order_scores[item.order_id] ||= Float::INFINITY
        order_scores[item.order_id] = [order_scores[item.order_id], index].min
      end

      orders.sort_by { |order| order_scores[order.id] || Float::INFINITY }
    end

    def assign_order_to_tote(order, position)
      return unless order

      total_position = position - 1
      current_row_position = 0
      current_row = nil

      @cart.cart_rows.each do |row|
        if total_position < current_row_position + row.row_count
          current_row = row
          break
        end
        current_row_position += row.row_count
      end

      return unless current_row

      position_in_row = (total_position - current_row_position) + 1
      tote_id = "#{current_row.row_name}-#{position_in_row}-#{@cart.cart_id}"

      tote = CartTote.find_by(tote_id: tote_id)
      if tote.assign_order(order)
        order.update(
          assigned_cart_tote_id: tote_id,
          assigned_user_id: @current_user.id,
          status: 'pick_in_progress'
        )

        @result['data']['assigned_orders'] << {
          order_id: order.id,
          tote_position: position
        }
      else
        @result['status'] = false
        @result['error_messages'] << "Order #{order.id} does not fit in any tote"
      end
    end
  end
end
