# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_import_summary do
    status { nil }
    import_summary_type { 'import_orders' }
  end
end
