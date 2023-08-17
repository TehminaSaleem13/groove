# frozen_string_literal: true

FactoryBot.define do
    factory :origin_store do
      association :store
      origin_store_id { rand(1..10) }
      recent_order_details { "DAN GUTTING - 101" }
      sequence(:store_name) { |n| "store-#{n}" }
    end
end