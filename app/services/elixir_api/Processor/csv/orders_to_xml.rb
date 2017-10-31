module ElixirApi
  module Processor
    module CSV
      # CAll Elixir Api to Generate XML data for each Order
      # And call the DB import API with the xml data for each order
      class OrdersToXML < ElixirApi::Processor::CSV::Base
        attr_reader :order_params

        def initialize(order_params)
          @order_params = order_params
          set_file_size
          @order_params['params'].merge!(
            import_summary_id: find_or_create_csvimportsummary.id
          )
        end

        def call
          HTTParty.post(
            'http://0.0.0.0:4001/api/process/import',
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

        private

        def find_or_create_csvimportsummary
          summary_params = { file_name: file_name.strip, import_type: 'Order' }
          summary = find_summary
          return summary if summary.present?

          summary_params[:file_size] = file_size
          CsvImportSummary.create(summary_params)
        end

        def set_file_size
          order_params['params'].merge!(
            file_size: (order_params['data'].bytesize.to_f / 1024).round(4)
          )
        end

        def find_summary
          CsvImportLogEntry.where('created_at<?', today_start).delete_all
          CsvImportSummary.where('created_at<?', today_start).destroy_all
          CsvImportSummary.where(
            'file_name=? and import_type=? and created_at>=? and created_at<=? and file_size=?',
            file_name.strip, 'Order', today_start, today_end, file_size
          ).last
        end

        def today_start
          DateTime.now.beginning_of_day
        end

        def today_end
          DateTime.now.end_of_day
        end

        def file_name
          order_params['params'][:file_name]
        end

        def file_size
          order_params['params'][:file_size]
        end
      end
    end
  end
end
