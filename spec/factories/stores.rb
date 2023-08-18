# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :store do
    name { 'MyString' }
    status { false }
    store_type { 'system' }
    order_date { '2013-08-29' }
    inventory_warehouse

    trait :shopify do
      store_type { 'Shopify' }
      shopify_credential
    end
  end
end
