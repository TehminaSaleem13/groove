# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :csv_mapping do
    store_id {1}
    order_map {"MyText"}
    product_map {"MyText"}
  end
end
