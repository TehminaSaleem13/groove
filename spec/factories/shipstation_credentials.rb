# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :shipstation_credential, class: 'ShipstationCredential' do
    username { 'MyString' }
    password { 'MyString' }
  end
end
