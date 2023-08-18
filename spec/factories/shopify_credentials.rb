# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :shopify_credential do
    shop_name { 'MyString' }
    access_token { 'MyString' }
  end
end
