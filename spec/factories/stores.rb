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

    trait :shopline do
      store_type { 'Shopline' }
      shopline_credential
    end

    trait :csv do
      store_type { 'CSV' }
      name { 'GP TEST - CSV' }
      status { true }
    end
  end
end
