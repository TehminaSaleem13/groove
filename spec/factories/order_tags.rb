# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_tag do
    name "Sample Tag"
    color "#FFFFFF"
    mark_place "bottom"
  end
end
