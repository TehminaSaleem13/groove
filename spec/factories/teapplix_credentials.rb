# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :teapplix_credential do
    store_id { 1 }
    account_name { 'MyString' }
    username { 'MyString' }
    password { 'MyString' }
  end
end
