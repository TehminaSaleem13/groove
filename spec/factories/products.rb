# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product do
    store_product_id "MyString"
    name "MyString"
    product_type "MyString"
    store nil
  end
end
