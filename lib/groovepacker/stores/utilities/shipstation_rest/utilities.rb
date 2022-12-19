# frozen_string_literal: true

module Groovepacker
  module Stores
    module Utilities
      module ShipstationRest
        class Utilities < Groovepacker::Stores::Utilities::Utilities
          def verify_tags(tags)
            handler = get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = {
              verification_result: true,
              message: ''
            }
            tags.each do |tag|
              if client.get_tag_id(tag) == -1
                result[:verification_result] = false
                result[:message] << ', ' if result[:message].present?
                result[:message] << "#{tag} Tag not found "
              else
                result[:message] << ', ' if result[:message].present?
                result[:message] << "#{tag} Tag found "
              end
            end
            # result[:message] =
            #   "Tags are available in your shipstation account." if result[:verification_result]
            result
          end
        end
      end
    end
  end
end
