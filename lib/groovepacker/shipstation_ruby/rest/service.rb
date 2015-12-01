module Groovepacker
  module ShipstationRuby
    module Rest
      # Shipstation Ruby Rest Service
      class Service
        attr_accessor :auth, :endpoint

        def initialize(api_key, api_secret)
          fail ArgumentError unless api_key && api_secret
          @auth = { api_key: api_key, api_secret: api_secret }
          @endpoint = 'https://ssapi.shipstation.com'
        end

        def post(query, body)
          response = HTTParty.post("#{@endpoint}#{query}",
                                     body: body,
                                     headers: headers)
          handle_exceptions(response)
          response
        end

        def query(query)
          response = nil
          trial_count = 0
          loop do
            puts "loop #{trial_count}"
            response = HTTParty.get("#{@endpoint}#{query}",
                                    headers: headers, 
                                    debug_output: $stdout)
            handle_response(response, trial_count) ? break : trial_count += 1
            break if trial_count >= 5
          end
          handle_exceptions(response)
          response
        end

        private

        def headers
          { 'Authorization' => 'Basic ' + Base64.encode64(@auth[:api_key] + ':' +
            @auth[:api_secret]).gsub(/\n/, '') }
        end

        def error_status_codes
          [500, 401]
        end
        def handle_response(response, trial_count)
          successful_response = false
          if error_status_codes.include?(response.code) ||
             (response.code == 504 && trial_count == 4)
            handle_exceptions(response)
          elsif response.code == 504
            sleep(5)
          else
            successful_response = true
          end
          successful_response
        end

        def handle_exceptions(response)
          fail Exception, 'Authorization with Shipstation store failed.' \
            ' Please check your API credentials' if response.code == 401
          fail Exception, response.inspect if response.code == 500
          fail Exception, 'Please contact support team. Gateway timeout error'\
            ' from Shipstation API.' if response.code == 504
        end 
      end
    end
  end
end
