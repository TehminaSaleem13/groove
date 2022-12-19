# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_item_kit_product_scan_time do
    scan_start { '2015-07-17 00:51:46' }
    scan_end { '2015-07-17 00:51:46' }
    order_item_kit_product_id { 1 }
  end
end
