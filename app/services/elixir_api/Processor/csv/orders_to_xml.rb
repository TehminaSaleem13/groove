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
              'order_params' => order_params.merge(mapping: generate_mapping)
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
        end

        private

        def generate_mapping
          order_params['params'][:map]
            .each_with_object({}) do |map_single, mapping|
            map_single_first_value = map_single[1].present? && map_single[1]['value']

            next mapping unless map_single_first_value &&
                                map_single_first_value != 'none'

            mapping[map_single_first_value] = {
              position: map_single[0].to_i,
              action:  map_single[1][:action] || 'skip'
            }
          end
        end
      end
    end
  end
end
