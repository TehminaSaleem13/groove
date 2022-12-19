# frozen_string_literal: true

module Groovepacker
  module ShipstationRuby
    class Collection
      attr_accessor :client, :resource

      def initialize(client, resource)
        @client = client
        @resource = resource
      end

      def find(id)
        @client.send(@resource.to_s, id)
        result = @client.execute
        single_result = result.first
        json_hash = JSON.parse(single_result.to_json)
        json_rash = Hashie::Rash.new(json_hash)
        json_rash
      end

      def all
        @client.send(@resource.to_s)
        results = @client.execute
        formatted_results = []
        results.each do |result|
          result_hash = JSON.parse(result.to_json)
          result_rash = Hashie::Rash.new(result_hash)
          formatted_results.push(result_rash)
        end
        formatted_results
      end

      def where(filters = {})
        final_string = ''
        final_string_array = []
        filters.each do |attribute, value|
          shipstation_style_attribute = attribute.to_s.classify.gsub(/Id/, 'ID')
          if value.is_a?(Integer) || value == true || value == false
            filter_string = "#{shipstation_style_attribute} eq #{value}"
          elsif value.is_a?(Time)
            value = value.to_datetime
            filter_string = "#{shipstation_style_attribute} gt datetime'#{value}'"
          else
            filter_string = "#{shipstation_style_attribute} eq '#{value}'"
          end

          final_string_array << filter_string
        end
        final_string = final_string_array.join(' and ')
        @client.send(@resource.to_s).filter(final_string.to_s)
        results = @client.execute
        formatted_results = []
        results.each do |result|
          result_hash = JSON.parse(result.to_json)
          result_rash = Hashie::Rash.new(result_hash)
          formatted_results.push(result_rash)
        end
        formatted_results
      end

      def update_primary_location(location, sku)
        final_string_array = []
        sku_string = "SKU eq '#{sku}'"
        final_string_array << sku_string
        final_string = final_string_array.join(' and ')
        @client.send(@resource.to_s).filter(final_string.to_s)
        result = @client.execute
        result = result.first
        unless location.nil? || location == ''
          result.WarehouseLocation = location
          @client.update_object(result)
          @client.save_changes
        end
      end
    end
  end
end
