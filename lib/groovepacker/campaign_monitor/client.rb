module Groovepacker
  module CampaignMonitor
    class Client < Base

      def add_subscriber_to_lists
        body_params = { 
            "EmailAddress" => @subscriber.email,
            "Name" => @subscriber.tenant_name
          }
        begin
          post("https://api.createsend.com/api/v3.1/subscribers/#{ENV['CAMPAIGN_MONITOR_NEW_CUSTOMER_LIST_ID']}.json", body_params)
          post("https://api.createsend.com/api/v3.1/subscribers/#{ENV['CAMPAIGN_MONITOR_ALL_CUSTOMERS_LIST_ID']}.json", body_params)
          delete("https://api.createsend.com/api/v3.1/subscribers/#{ENV['CAMPAIGN_MONITOR_LEADS_LIST_ID']}.json?email=#{@subscriber.email}")
        rescue Exception => ex
        end
      end

      def add_cost_calculator_lists(saving, error, email)
        body_params = {
           "EmailAddress" => email,
            "CustomFields" =>
              [{
               "key" => "CostPerError",
               "value" => error.to_f
               },
               {
                "key" => "ErrorCostPerMonth",
                "value" => saving.to_f
              }]
          }
        begin
          post("https://api.createsend.com/api/v3.1/subscribers/#{ENV['CAMPAIGN_MONITOR_CALCULATOR_LIST_ID']}.json", body_params)
        rescue Exception => ex
        end
      end

      def remove_subscriber_from_lists
        begin
          delete("https://api.createsend.com/api/v3.1/subscribers/#{ENV['CAMPAIGN_MONITOR_NEW_CUSTOMER_LIST_ID']}.json?email=#{@subscriber.email}")
          delete("https://api.createsend.com/api/v3.1/subscribers/#{ENV['CAMPAIGN_MONITOR_ALL_CUSTOMERS_LIST_ID']}.json?email=#{@subscriber.email}")
        rescue Exception => ex
        end
      end

      def remove_subscriber_from_new_customers_list
        begin
          delete("https://api.createsend.com/api/v3.1/subscribers/#{ENV['CAMPAIGN_MONITOR_NEW_CUSTOMER_LIST_ID']}.json?email=#{@subscriber.email}")
        rescue Exception => ex
        end
      end
      
      private
        def get(url, query_opts={})
          response = HTTParty.get(url,
                                  query: query_opts,
                                  basic_auth: auth,
                                  headers: {
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  }
                                )
          response.parsed_response
        end

        def put(url, body={})
          response = HTTParty.put(url,
                                  body: body.to_json,
                                  basic_auth: auth,
                                  headers: {
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  }
                                )
        end

        def post(url, body={})
          response = HTTParty.post(url,
                                  body: body.to_json,
                                  basic_auth: auth,
                                  headers: {
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  }
                                )
        end

        def delete(url, body={})
          response = HTTParty.delete(url,
                                  body: body.to_json,
                                  basic_auth: auth,
                                  headers: {
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  }
                                )
        end

        def auth
          {:username => api_key}
        end

    end
  end
end
