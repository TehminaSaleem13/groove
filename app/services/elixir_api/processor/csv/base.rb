# frozen_string_literal: true

module ElixirApi
  module Processor
    module CSV
      # Keep generic methods for the Elixir services here
      class Base < ServiceInit
        IMPORT_ROUTES = {
          'order' => '/orders/import_xml'
        }.freeze

        def host_url(tenant)
          "#{protocol}://#{tenant}.#{ENV['IMPORT_SITE_HOST']}"
        end

        def auth_params
          {
            'route' => '/auth/v1/login',
            'username' => ENV['ADMIN_USERNAME'],
            'password' => ENV['ADMIN_PASSWORD']
          }
        end

        def generate_mapping(map)
          delete_index = 0
          map.each_with_object({}) do |map_out, _map_now|
            map_single_first_name = map_out[1].present? && map_out[1]['name']
            map.delete(delete_index.to_s) if map_single_first_name == 'Unmapped'
            delete_index += 1
          end

          map.each_with_object({}) do |map_single, mapping|
            map_single_first_value = map_single[1].present? &&
                                     map_single[1]['value']
            next mapping unless map_single_first_value &&
                                map_single_first_value != 'none'

            mapping[map_single_first_value] = {
              position: map_single[0].to_i,
              action: map_single[1][:action] || 'skip'
            }
          end
        end

        private

        def protocol
          Rails.env.development? ? 'http' : 'https'
        end
      end
    end
  end
end
