# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order do
    status "MyString"
    storename "MyString"
    customercomments "MyString"
    store nil
  end
end
