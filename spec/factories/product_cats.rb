# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :product_cat do
    category { 'MyString' }
    product { nil }
  end
end
