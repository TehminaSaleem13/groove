# frozen_string_literal: true

class CsvMapping < ApplicationRecord
  # attr_accessible :order_map, :product_map, :store_id, :order_csv_map, :product_csv_map
  belongs_to :store
  belongs_to :product_csv_map, class_name: 'CsvMap', optional: true
  belongs_to :order_csv_map, class_name: 'CsvMap', optional: true
  belongs_to :kit_csv_map, class_name: 'CsvMap', optional: true
  serialize :order_map
  serialize :product_map
end
