# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_tag do
    name {"Sample Tag"}
    color {"#FFFFFF"}
    mark_place {"bottom"}
  end
end
