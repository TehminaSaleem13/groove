# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_kit_sku, :class => 'ProductKitSkus' do
    product nil
    option_product_id 0
    qty 1
  end
end
