module Groovepacker
  module ShipstationRuby
    module Rest
      class Client
        attr_accessor :auth, :client, :endpoint

        def initialize(api_key, api_secret)
          raise ArgumentError unless api_key && api_secret
          @auth = {:api_key => api_key, :api_secret => api_secret}
          @endpoint = "https://ssapi.shipstation.com"
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
            response = HTTParty.get('https://ssapi.shipstation.com/Orders/List?orderStatus=' + 
              status + '&page=' + page_index.to_s + '&pageSize=100' + orderDateStart,
              headers: {
                "Authorization" => "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, ''),
                "X-Mashape-Key" => "E6cSux0BVQmshJh0VacUkqXP1sJgp1I1APKjsntC26JSOTy0pP",
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
          response = HTTParty.get('https://ssapi.shipstation.com/Products?showInactive=false',
            headers: {
              "Authorization" => "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, ''),
              "X-Mashape-Key" => "E6cSux0BVQmshJh0VacUkqXP1sJgp1I1APKjsntC26JSOTy0pP"
            })
          handle_exceptions(response)
          response.parsed_response
        end

        def get_tracking_number(orderNumber)
          tracking_number = nil
          unless orderNumber.nil?
            orderNumber = '&orderNumber=' + orderNumber.to_s
            Rails.logger.info "Getting shipment with order number: " + orderNumber
            response = HTTParty.get('https://ssapi.shipstation.com/Shipments/List?' + 
                'page=1&pageSize=100' + URI.encode(orderNumber),
                headers: {
                  "Authorization" => "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, ''),
                  "X-Mashape-Key" => "E6cSux0BVQmshJh0VacUkqXP1sJgp1I1APKjsntC26JSOTy0pP"
                })
            handle_exceptions(response)
            unless response.parsed_response["shipments"].nil? ||
             response.parsed_response["shipments"].empty?
              tracking_number = response.parsed_response["shipments"].first["trackingNumber"]
            end
          end
          tracking_number
        end

        def update_order(orderId, order)
          Rails.logger.info "Updating order with orderId: " + orderId.to_s
          response = HTTParty.post('https://ssapi.shipstation.com/Orders/CreateOrder',{
            body: JSON.dump(order),
            headers: {
              "Authorization" => "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, ''),
              "X-Mashape-Key" => "E6cSux0BVQmshJh0VacUkqXP1sJgp1I1APKjsntC26JSOTy0pP",
              "Content-Type" => "application/json",
              "Accept" => "application/json"
            }, :debug_output => $stdout})
          handle_exceptions(response)
          puts response.inspect
          response
        end

        def get_order(orderId)
          puts "retrieving order"
          Rails.logger.info "Getting orders with orderId: " + orderId
          response = HTTParty.get('https://ssapi.shipstation.com/Orders/' + orderId,
            headers: {
              "Authorization" => "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, ''),
              "X-Mashape-Key" => "E6cSux0BVQmshJh0VacUkqXP1sJgp1I1APKjsntC26JSOTy0pP"
            })
          handle_exceptions(response)
          puts response.inspect
          response
        end

        def get_tag_id(tag)
          response = HTTParty.get(@endpoint + '/accounts/listtags',
            headers: {
              "Authorization" => authorization_token
          })
          handle_exceptions(response)
          tags = response.parsed_response
          index = tags.empty?? nil : tags.index{|x| x["name"] == tag }
          index.nil?? -1 : tags[index]["tagId"]
        end

        def get_orders_by_tag(tag)
          tag_id = get_tag_id(tag)
          page_index = 1
          response = {}
          response["orders"] = []
          unless tag_id == -1
            ["awaiting_payment", "awaiting_shipment", "shipped", 
              "on_hold", "cancelled"].each do |status|
              orders = find_orders_by_tag_and_status(tag_id, status)
              response["orders"] = response["orders"] + orders unless orders.nil?
            end
          end
          response
        end

        def find_orders_by_tag_and_status (tag_id, status)
          page_index = 1
          total_pages = 0

          begin
            response = HTTParty.get(@endpoint + '/orders/listbytag?orderStatus=' + 
              status + '&tagId=' + tag_id.to_s + '&page=' + page_index.to_s + '&pageSize=100',
                headers: {
                  "Authorization" => authorization_token
                }
              )
            total_pages = response.parsed_response["pages"]
            page_index = page_index + 1
          end while (page_index <= total_pages)
          handle_exceptions(response)
          response["orders"]
        end

        def remove_tag_from_order(order_id, tag_id)
          response = HTTParty.post(@endpoint + '/orders/removetag', {
            body: {orderId: order_id, tagId: tag_id},
            headers: {
              "Authorization" => authorization_token
            }
          })
          handle_exceptions(response)
        end

        def add_tag_to_order(order_id, tag_id)
          response = HTTParty.post(@endpoint + '/orders/addtag', {
            body: {orderId: order_id, tagId: tag_id},
            headers: {
              "Authorization" => authorization_token
            }
          })
          handle_exceptions(response)
        end

        def inspect
          "#<ShipStationRuby::Client:#{object_id}>"
        end

        private

        def authorization_token
          "Basic "+ Base64.encode64(@auth[:api_key] + ":" + @auth[:api_secret]).gsub(/\n/, '')
        end

        def handle_exceptions(response)
          raise Exception, "Authorization with Shipstation store failed. Please check your API credentials" if response.code == 401
          raise Exception, response.inspect if response.code == 500
        end
      end
    end
  end
end