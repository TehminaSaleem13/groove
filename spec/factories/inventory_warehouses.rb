# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :inventory_warehouse do
    name {"Manhattan warehouse"}
    location {"New Jersey"}
    status { "inactive"}
  end
end
