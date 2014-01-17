# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_tag do
    name "Contains New"
    color "#FF0000"
    mark_place "bottom"
  end
end
