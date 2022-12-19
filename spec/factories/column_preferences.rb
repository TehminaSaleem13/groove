# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :column_preference do
    user { nil }
    identifier { 'MyString' }
  end
end
