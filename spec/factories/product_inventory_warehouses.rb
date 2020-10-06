# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :product_inventory_warehouse, :class => 'ProductInventoryWarehouses' do
    location {"MyString"}
    qty {1}
    product {nil}
    location_primary {'A1' }
    location_secondary {'H4'}
  end
end
