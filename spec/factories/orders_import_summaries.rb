# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :orders_import_summary do
    total_retrieved { 1 }
    success_imported { 1 }
    previous_imported { 1 }
    status { false }
    error_message { 'MyString' }
    store { nil }
  end
end
