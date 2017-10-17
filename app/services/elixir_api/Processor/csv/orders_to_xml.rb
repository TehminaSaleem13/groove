module ElixirApi
  module Processor
    module CSV
      # CAll Elixir Api to Generate XML data for each Order
      # And call the DB import API with the xml data for each order
      class OrdersToXML < ElixirApi::Processor::CSV::Base
        attr_reader :order_params

        def initialize(order_params)
          @order_params = order_params
        end

        def call
          HTTParty.post(
            'http://0.0.0.0:4000/api/process/import',
            body: {
              'for' => 'order', 'csv' => 'true',
              'order_params' => order_params.merge(
                'mapping' => generate_mapping(order_params['params'][:map]),
                'host_url' => host_url(order_params['tenant']),
                'import_api_route' => IMPORT_ROUTES['order'],
                'auth_params' => auth_params
              )
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
        end
      end
    end
  end
end
