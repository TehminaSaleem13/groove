# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :access_restriction do
    num_import_sources { 10 }
    num_shipments { 1000 }
    total_scanned_shipments { 0 }
  end
end
