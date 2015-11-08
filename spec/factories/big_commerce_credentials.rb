# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :big_commerce_credential do
    store_id 1
    shop_name "MyString"
    store_hash "MyString"
    access_token "MyString"
  end
end
