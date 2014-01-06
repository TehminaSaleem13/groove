# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_item_kit_product do
    order_item nil
    product_kit_skus nil
    scanned_status "unscanned"
    scanned_qty 0
  end
end
