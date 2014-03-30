# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :sold_inventory_warehouse do
    product_inventory_warehouses_id 1
    sold_qty 1
    sold_date "2014-03-30 23:00:43"
  end
end
