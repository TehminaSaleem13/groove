# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :shopify_credential do
    shop_name { 'myteststore' }
    access_token { 'shpat_1234567890987654321512345678754345' }
  end
end
