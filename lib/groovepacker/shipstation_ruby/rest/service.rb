# frozen_string_literal: true

module Groovepacker
  module ShipstationRuby
    module Rest
      # Shipstation Ruby Rest Service
      class Service
        attr_accessor :auth, :endpoint

        def initialize(api_key, api_secret)
          raise ArgumentError unless api_key && api_secret

          @auth = { api_key: api_key, api_secret: api_secret }
          @endpoint = 'https://ssapi.shipstation.com'
        end

        def query(query, body, method, type = nil)
          response = nil
          trial_count = 0
          loop do
            puts "loop #{trial_count}" unless Rails.env == 'test'
            begin
              response = send(query, body, method)
              return response if type == 'create_label'
            rescue Exception => e
              handle_request_exception(e, trial_count)
              trial_count += 1
              next
            end
            if handle_response(response, trial_count)
              break
            else
              trial_count += 1
            end
            break if trial_count >= 5
          end
          handle_exceptions(response)
          response
        end

        private

        def headers
          { 'Authorization' => 'Basic ' + Base64.encode64(@auth[:api_key] + ':' +
            @auth[:api_secret]).delete("\n") }
        end

        def error_status_codes
          [500, 504, 401]
        end

        def handle_response(response, trial_count)
          successful_response = false
          if error_status_codes.include?(response.code) && trial_count == 4
            handle_exceptions(response)
          elsif response.code == 504
            sleep(5)
          elsif response.code == 401
            query = @query
            end_point = @endpoint
            current_tenant = Apartment::Tenant.current
            ImportMailer.shipstation_unauthorized(response, query, headers, end_point).deliver if %w[morgan islandwatersports gunmagwarehouse warmyourfloor icracked].include?(current_tenant)
            sleep(2)
          else
            successful_response = true
          end
          successful_response
        end

        def handle_request_exception(ex, socket_count)
          if socket_count <= 5
            # send email
            sleep(5)
          else
            # send email
            raise Exception, ex.message
          end
        end

        def send(query, body, method)
          debug_output = Rails.env == 'development' ? $stdout : false
          @query = query
          if method == 'get'
            HTTParty.get("#{@endpoint}#{query}", headers: headers, debug_output: debug_output)
          elsif method == 'put'
            HTTParty.put("#{@endpoint}#{query}", body: body, headers: headers.merge('Content-Type': 'application/json'), debug_output: debug_output)
          else
            HTTParty.post("#{@endpoint}#{query}", body: body, headers: headers, debug_output: debug_output)
          end
        end

        def handle_exceptions(response)
          raise Exception, response.inspect if response.code == 401

          # fail Exception, JSON.parse(response.inspect) if response.code == 401
          # fail Exception, 'Authorization with Shipstation store failed.' \
          #   ' Please check your API credentials' if response.code == 401
          if response.code == 500
            query = @query
            end_point = @endpoint
            current_tenant = Apartment::Tenant.current
            ImportMailer.shipstation_unauthorized(response, query, headers, end_point).deliver if %w[morgan icracked toktokcase gunmagwarehouse].include?(current_tenant)
            raise Exception, response.inspect
          end
          if response.code == 504
            raise Exception, 'Please contact support team. Gateway timeout error'\
              ' from Shipstation API.'
          end
        end
      end
    end
  end
end
