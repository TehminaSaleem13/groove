# frozen_string_literal: true

module ScanPack
  class CartScanService
    include ScanPackHelper

    def initialize(cart, current_user, params)
      @cart = cart
      @current_user = current_user
      @params = params
      @result = {
        'status' => true,
        'error_messages' => [],
        'success_messages' => [],
        'data' => {}
      }
    end

    def run
      return handle_validation if pending_orders?

      case @params[:cart_action]
      when 'restart'
        reset_cart
        assign_orders
      when 'cancel'
        handle_cancel
      else
        assign_orders
      end
    end

    private

    def pending_orders?
      validation_service = CartValidationService.new(@cart.id, @current_user)
      @validation_result = validation_service.validate
      @validation_result['data']['has_pending_orders']
    end

    def handle_validation
      @validation_result
    end

    def reset_cart
      Order.where(assigned_cart_tote_id: @cart.id).update_all(
        assigned_cart_tote_id: nil,
        assigned_user_id: nil,
        status: 'awaiting'
      )
    end

    def assign_orders
      assignment_service = OrderAssignmentService.new(@cart, @current_user)
      assignment_service.assign_orders
    end

    def handle_cancel
      {
        'status' => true,
        'data' => { 'next_state' => 'scanpack.rfo' }
      }
    end
  end
end