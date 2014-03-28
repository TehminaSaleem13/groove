# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :store do
    name "MyString"
    status false
    store_type "system"
    order_date "2013-08-29"
  end
end
