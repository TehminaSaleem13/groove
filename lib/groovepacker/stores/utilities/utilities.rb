# frozen_string_literal: true

module Groovepacker
  module Stores
    module Utilities
      class Utilities
        def initialize(handler)
          self.handler = handler
        end

        def verify_tags(_tags)
          {}
        end

        def get_handler
          handler
        end

        def build_result
          {
            messages: [],
            previous_imported: 0,
            success_imported: 0,
            total_imported: 0,
            debug_messages: [],
            status: true
          }
        end

        protected

        attr_accessor :handler
      end
    end
  end
end
