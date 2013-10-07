# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order do
    status "MyString"
    storename "MyString"
    customercomments "MyString"
    store nil
    increment_id 1
    order_placed_time "2013-09-03 23:21:02"
    sku "MyString"
    customer_comments "MyText"
    store_id 1
    qty 1
    price "9.99"
    firstname "MyString"
    lastname "MyString"
    email "MyString"
    address_1 "MyText"
    address_2 "MyText"
    city "MyString"
    state "MyString"
    postcode "MyString"
    country "MyString"
    method "MyString"
  end
end
