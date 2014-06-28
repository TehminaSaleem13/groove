module Groovepacker
  module Store
    module Importers
      class Importer
        def initialize(handler)
          self.handler = handler
        end

        def import
          {}
        end

        def import_single(hash)
          {}
        end
        
        def get_handler
          self.handler
        end

        def build_result
          {
            messages: [],
            previous_imported: 0,
            success_imported: 0,
            total_imported: 0,
            debug_messages:[],
            status: true
          }
        end

        protected
          attr_accessor :handler


      end
    end
  end
end