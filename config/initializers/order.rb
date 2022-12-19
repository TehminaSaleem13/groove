# frozen_string_literal: true

module MWS
  module API
    class Order < Base
      def_request %i[list_orders list_orders_by_next_token],
                  verb: :get,
                  uri: '/Orders/2013-09-01',
                  version: '2013-09-01',
                  lists: {
                    order_status: 'OrderStatus.Status'
                  },
                  mods: [
                    ->(r) { r.orders = r.orders.order if r.orders }
                  ]

      def_request %i[list_order_items list_order_items_by_next_token],
                  verb: :get,
                  uri: '/Orders/2013-09-01',
                  version: '2013-09-01',
                  mods: [
                    ->(r) { r.order_items = [r.order_items.order_item].flatten }
                  ]

      def_request :get_order,
                  verb: :get,
                  uri: '/Orders/2013-09-01',
                  version: '2013-09-01',
                  lists: {
                    amazon_order_id: 'AmazonOrderId.Id'
                  },
                  mods: [
                    ->(r) { r.orders = [r.orders.order].flatten }
                  ]
    end
  end
end
