# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_item_kit_product do
    order_item nil
    product_kit_sku nil
    scanned_status "MyString"
    scanned_qty 1
  end
end
