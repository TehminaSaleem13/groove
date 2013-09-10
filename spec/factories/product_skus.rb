# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_sku do
    sku "MyString"
    purpose "MyString"
    product nil
  end
end
