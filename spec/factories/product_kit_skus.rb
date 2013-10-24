# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_kit_sku, :class => 'ProductKitSkus' do
    product nil
    sku "MyString"
  end
end
