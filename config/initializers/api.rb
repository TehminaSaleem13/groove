# frozen_string_literal: true

module Mws::Apis::Feeds
  class Api
    attr_reader :products, :images, :prices, :shipping, :inventory

    def initialize(connection, defaults = {})
      raise Mws::Errors::ValidationError, 'A connection is required.' if connection.nil?

      @connection = connection
      defaults[:version] ||= '2013-09-01'
      @defaults = defaults

      @products = self.for :product
      @images = self.for :image
      @prices = self.for :price
      @shipping = self.for :override
      @inventory = self.for :inventory
    end
  end
end
