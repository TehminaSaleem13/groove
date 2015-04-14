# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :shopify_credential do
    shop_name "MyString"
    access_token "MyString"
    store_id 1
  end
end
