# frozen_string_literal: true

module ElixirApi
  module Processor
    module CSV
      # CAll Elixir Api to Generate XML data for each Order
      # And call the DB import API with the xml data for each order
      class OrdersToXML < ElixirApi::Processor::CSV::Base
        attr_reader :order_params

        def initialize(order_params)
          @order_params = order_params
          @order_params['params'][:import_summary_id] = find_summary
          tenant = Apartment::Tenant.current
          $redis.set("total_orders_#{tenant}", Order.count)
          $redis.set("new_order_#{tenant}", 0)
          $redis.set("update_order_#{tenant}", 0)
          $redis.set("skip_order_#{tenant}", 0)
          last_order = begin
                         Order.last.created_at
                       rescue StandardError
                         nil
                       end
          $redis.set("last_order_#{tenant}", last_order)
          $redis.set("import_action_#{tenant}", order_params['params'][:import_action])
          $redis.set("file_name_#{tenant}", order_params['params'][:file_name])
          $redis.set("is_create_barcode_#{tenant}", GeneralSetting.last.create_barcode_at_import)
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
            'db_port' => ENV['DB_PORT'] || 3306,
            'tenant_offset' => tenant_offset
            # 'database' => Rails.configuration.database_configuration[Rails.env]['database']
          }
        end

        def redis_key_for_elixir_pid
          "#{order_params['tenant']}_elixir_order_import_pid"
        end

        def tenant_offset
          setting_time_zone = GeneralSetting.first.new_time_zone
          return "+0000" unless setting_time_zone

          time_zone = ActiveSupport::TimeZone.new(setting_time_zone)
          current_time = Time.now.in_time_zone(time_zone)
          current_time.formatted_offset.gsub(':', '')
        end

        def save_elixir_process_pid(response)
          key = redis_key_for_elixir_pid
          val = response['data']['pid'].to_s
          Rails.cache.write(key, val)
        rescue StandardError
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
          OrderImportSummary.find_by_status('not_started').id
        rescue StandardError
          OrderImportSummary.create(import_summary_type: 'import_orders', status: 'not_started', user_id: 2).id
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
