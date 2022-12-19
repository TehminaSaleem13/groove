# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :product_lot do
    lot_number { 'LOT' }
    product { nil }
  end
end
