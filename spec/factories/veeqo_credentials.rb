# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :veeqo_credential do
    api_key { 'jcsbjsjknbskcjcbskj' }
    last_imported_at { Time.now }
  end
end
