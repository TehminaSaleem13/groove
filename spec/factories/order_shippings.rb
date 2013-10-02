# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_shipping do
    firstname "MyString"
    lastname "MyString"
    email "MyString"
    streetaddress1 "MyString"
    streetaddress2 "MyString"
    city "MyString"
    region "MyString"
    postcode "MyString"
    country "MyString"
    description "MyString"
  end
end
