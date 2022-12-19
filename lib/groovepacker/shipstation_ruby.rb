# frozen_string_literal: true

require 'rash'
require 'ruby_odata'

require 'shipstation_ruby/client'
require 'shipstation_ruby/collection'

module ShipStationRuby
  API_BASE = 'https://data.shipstation.com/1.1'

  class ShipStationRubyError < StandardError
  end

  class AuthenticationError < ShipStationRubyError
  end
  class ConfigurationError < ShipStationRubyError
  end

  class << self
    def username
      defined? @username && @username || raise(
        ConfigurationError, 'ShipStationRuby username not configured'
      )
    end

    attr_writer :username

    def password
      defined? @password && @password || raise(
        ConfigurationError, 'ShipStationRuby password not configured'
      )
    end

    attr_writer :password
  end
end
