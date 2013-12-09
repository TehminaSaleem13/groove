# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product do
    store_product_id "IPHONE456"
    name "Apple iPhone 5S"
    product_type "Smartphone"
    store_id 1
    status "active"
  end
end
