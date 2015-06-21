module Groovepacker
  module Dashboard
    module Stats
      class Base
        attr_accessor :duration

        def initialize(duration)
          @duration = duration
        end
      
      end
    end
  end
end