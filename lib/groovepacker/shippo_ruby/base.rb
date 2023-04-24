module Groovepacker
  module ShippoRuby
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :shippo_credential

      def initialize(shippo_credential)
        self.shippo_credential = shippo_credential
      end
    end
  end
end
