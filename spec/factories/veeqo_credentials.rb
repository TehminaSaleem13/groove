# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :veeqo_credential do
    api_key { 'jcsbjsjknbskcjcbskj' }
    last_imported_at { Time.now }
    shipped_status { true }
    awaiting_amazon_fulfillment_status { true }
    awaiting_fulfillment_status { true }
    import_shipped_having_tracking { true }
    gen_barcode_from_sku { true }
    allow_duplicate_order { true }
    shall_import_internal_notes { true }
    shall_import_customer_notes { true }
  end
end
