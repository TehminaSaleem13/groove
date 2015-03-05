# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :csv_map do
    type ""
    custom false
    map "MyText"
  end
end
