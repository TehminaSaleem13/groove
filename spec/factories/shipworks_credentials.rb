# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :shipworks_credential, class: 'ShipworksCredential' do
    auth_token { 'MyString' }
    store_id { 1 }
  end
end
