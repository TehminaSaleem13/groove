# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :column_preference do
    user nil
    identifier "MyString"
    shown "MyText"
    order "MyText"
  end
end
