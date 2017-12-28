module ElixirApi
  module Processor
    module CSV
      # CAll Elixir Api to Generate XML data for each Order
      # And call the DB import API with the xml data for each order
      class OrdersToXML < ElixirApi::Processor::CSV::Base
        attr_reader :order_params

        def initialize(order_params)
          @order_params = order_params
          @order_params['params'].merge!(
            import_summary_id: find_summary.id
          )
        end

        def self.cancel_import(tenant)
          HTTParty.post(
            "#{ENV['ELIXIR_API']}/api/process/terminate_process",
            body: {
              pid_list: Rails.cache.read("#{tenant}_elixir_order_import_pid")
            }
          )
        end

        def call
          response = HTTParty.post(
            "#{ENV['ELIXIR_API']}/api/process/import",
            body: {
              'for' => 'order', 'csv' => 'true',
              'order_params' => order_params.merge(
                'mapping' => generate_mapping(order_params['params'][:map]),
                'host_url' => host_url(order_params['tenant']),
                'import_api_route' => IMPORT_ROUTES['order'],
                'auth_params' => auth_params,
                'db_config' => set_db_config
              )
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

          save_elixir_process_pid(response)
        end

        private

        def set_db_config
          {
            'db_user' => ENV['DB_USERNAME'],
            'db_password' => ENV['DB_PASSWORD'],
            'db_host' => ENV['DB_HOST'],
            'db_port' => ENV['DB_PORT'] || 3306
          }
        end

        def redis_key_for_elixir_pid
          "#{order_params['tenant']}_elixir_order_import_pid"
        end

        def save_elixir_process_pid(response)
          key = redis_key_for_elixir_pid
          val = response['data']['pid'].to_s
          Rails.cache.write(key, val)
        end

        def find_elixir_process_pid
          Rails.cache.read(redis_key_for_elixir_pid)
        end

        # def set_file_size
        #   order_params['params'].merge!(
        #     file_size: (order_params['data'].bytesize.to_f / 1024).round(4)
        #   )
        # end

        def find_summary
          OrderImportSummary.find_by_status('not_started')
        end

        # def today_start
        #   DateTime.now.beginning_of_day
        # end

        # def today_end
        #   DateTime.now.end_of_day
        # end

        # def file_name
        #   order_params['params'][:file_name]
        # end

        # def file_size
        #   order_params['params'][:file_size]
        # end
      end
    end
  end
end
