# frozen_string_literal: true

module ScanPack
  class CartValidationService
    def initialize(cart_id, current_user)
      @cart_id = cart_id
      @current_user = current_user
      @result = {
        'status' => true,
        'error_messages' => [],
        'success_messages' => [],
        'data' => {
          'has_pending_orders' => false,
          'options' => []
        }
      }
    end

    def validate
      check_pending_orders
      @result
    end

    private

    def check_pending_orders
      pending_orders = Order.where(assigned_cart_tote_id: @cart_id)
                           .where.not(status: ['scanned', 'completed'])

      if pending_orders.exists?
        @result['data']['has_pending_orders'] = true
        @result['data']['options'] = [
          {
            'id': 'take_assignment',
            'label': 'Take assignment of these orders and continue scanning them. Progress will be maintained.'
          },
          {
            'id': 'restart',
            'label': 'Restart and un-assign all orders on the cart. Be sure to physically clear all totes on the cart. All progress on these orders will be lost.'
          },
          {
            'id': 'cancel',
            'label': 'Cancel. Leave this cart & scan a different cart to continue'
          }
        ]
      end
    end
  end
end