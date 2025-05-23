# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_item do
    sku { 'E-VEGAN-EPIC' }
    qty { 1 }
    price { '9.99' }
    row_total { '9.99' }
    order { nil }
    name { 'E VEGAN EPIC' }
    product_id { 1 }
  end
end
