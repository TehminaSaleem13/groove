module Groovepacker
  module Stores
    module Utilities
      module ShipstationRest
        class Utilities < Groovepacker::Stores::Utilities::Utilities
          def verify_tags(tags)
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = {
              verification_result: true,
              message: nil
            }
            tags.each do |tag|
              if client.get_tag_id(tag) == -1
                result[:verification_result] = false
                result[:message] = "#{tag} Tag is not available"
              end
            end
            result[:message] = 
              "Tags are available in your shipstation account." if result[:verification_result]
            result
          end
        end
      end
    end
  end
end
