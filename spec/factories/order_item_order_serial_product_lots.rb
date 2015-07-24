# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_item_order_serial_product_lot do
    order_item_id 1
    product_lot_id 1
    order_serial_id 1
  end
end
