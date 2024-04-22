# frozen_string_literal: true

module Groovepacker
  module VeeqoRuby
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :veeqo_credential

      def initialize(veeqo_credential)
        self.veeqo_credential = veeqo_credential
      end
    end
  end
end
