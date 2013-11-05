# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_inventory_warehouse, :class => 'ProductInventoryWarehouses' do
    location "MyString"
    qty 1
    product nil
  end
end
