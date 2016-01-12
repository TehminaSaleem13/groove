# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :shipping_easy_credential do
    store_id 1
    api_key "MyString"
    api_secret "MyString"
    import_ready_for_shipment false
    import_shipped false
    gen_barcode_from_sku false
  end
end
