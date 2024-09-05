# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :inventory_warehouse do
    sequence(:name) { |n| "Warehouse #{n}" }
    location { 'New Jersey' }
    status { 'inactive' }
  end
end
