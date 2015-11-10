# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :magento_rest_credential do
    store_id 1
    host "MyString"
    api_key "MyString"
    api_secret "MyString"
    import_images false
    import_categories false
  end
end
