# frozen_string_literal: true

module ScanPack
  class ScanToCartService
    include ScanPackHelper

    WORKFLOW_STATES = {
      awaiting_orders: 'awaiting_orders',
      pick_in_progress: 'pick_in_progress',
      picked: 'picked',
      scanned: 'scanned'
    }.freeze

    def initialize(current_user, cart, params)
      @current_user = current_user
      @cart = cart
      @params = params
      @result = {
        'status' => true,
        'error_messages' => [],
        'success_messages' => [],
        'data' => {
          'workflow_state' => WORKFLOW_STATES[:awaiting_orders]
        }
      }
    end

    def run
      validate_cart
      assign_orders if @result['status']
      assign_totes if @result['status']
      @result
    end

    private

    def validate_cart
      unless @cart.valid?
        @result['status'] = false
        @result['error_messages'] << 'Invalid cart configuration'
        return
      end

      if @cart.cart_rows.empty?
        @result['status'] = false
        @result['error_messages'] << 'Cart must have at least one row'
      end
    end

    def assign_orders
      assignment_service = OrderAssignmentService.new(@cart, @current_user)
      result = assignment_service.assign_orders

      if result['status']
        @result['success_messages'] << 'Orders assigned successfully'
        @result['data']['workflow_state'] = WORKFLOW_STATES[:pick_in_progress]
      else
        @result['status'] = false
        @result['error_messages'].concat(result['error_messages'])
      end
    end

    def assign_totes
      @cart.cart_rows.each do |row|
        (1..@cart.positions_per_row).each do |position|
          order = Order.find_by(
            assigned_cart_tote_id: @cart.id,
            assigned_tote_row: row.name,
            assigned_tote_position: position
          )
          if order
            @result['success_messages'] << "Order #{order.increment_id} assigned to tote position #{row.name}-#{position}"
          end
        end
      end
    end

  end
end