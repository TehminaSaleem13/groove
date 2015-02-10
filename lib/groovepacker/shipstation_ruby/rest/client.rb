module Groovepacker
  module ShipstationRuby
    module Rest
      class Client
        attr_accessor :auth, :client

        def initialize(api_key, api_secret)
          raise ArgumentError unless api_key && api_secret
          @auth = {:api_key => api_key, :api_secret => api_secret}
        end

        def get_orders(status, order_placed_after)
          Rails.logger.info "Getting orders with status: " + status
          orderDateStart = ''
          unless order_placed_after.nil?
            orderDateStart = '&orderDateStart=' + order_placed_after.to_s
            Rails.logger.info "Getting orders placed after: " + order_placed_after.to_s
          end
          page_index = 1
          combined_response = {}
          combined_response["orders"] = []
          begin
            response = HTTParty.get('https://shipstation.p.mashape.com/Orders/List?orderStatus=' + 
              status + '&page=' + page_index.to_s + '&pageSize=100' + orderDateStart,
              headers: {
                "Authorization" => "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, ''),
                "X-Mashape-Key" => "E6cSux0BVQmshJh0VacUkqXP1sJgp1I1APKjsntC26JSOTy0pP"
              })
            handle_exceptions(response)
            combined_response["orders"] = 
              combined_response["orders"] + 
                response.parsed_response["orders"] unless response.parsed_response["orders"].length == 0
            page_index = page_index + 1
          end while response.parsed_response["orders"].length > 0
          combined_response
        end

        def get_products
          Rails.logger.info "Getting all active products"
          response = HTTParty.get('https://shipstation.p.mashape.com/Products?showInactive=false',
            headers: {
              "Authorization" => "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, ''),
              "X-Mashape-Key" => "E6cSux0BVQmshJh0VacUkqXP1sJgp1I1APKjsntC26JSOTy0pP"
            })
          handle_exceptions(response)
          response.parsed_response
        end

        def inspect
          "#<ShipStationRuby::Client:#{object_id}>"
        end

        private

        def handle_exceptions(response)
          raise Exception, "Authorization with Shipstation store failed. Please check your API credentials" if response.code == 401
          raise Exception, response.body if response.code == 500
        end
      end
    end
  end
end