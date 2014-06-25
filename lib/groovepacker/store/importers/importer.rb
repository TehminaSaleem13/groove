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

        protected
          attr_accessor :handler
      end
    end
  end
end