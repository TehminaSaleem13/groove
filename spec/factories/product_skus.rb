# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_sku do
    sku "IPHONE5S"
    purpose "primary"
    product nil
  end
end
