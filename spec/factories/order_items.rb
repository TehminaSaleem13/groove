# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_item do
    sku "MyString"
    qty 1
    price "9.99"
    row_total "9.99"
    order nil
  end
end
