# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :inventory_warehouse do
    name "Manhattan warehouse"
    location "New Jersey"
    status "inactive"
  end
end
