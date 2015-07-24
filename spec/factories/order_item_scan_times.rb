# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_item_scan_time do
    scan_start "2015-07-16 18:41:51"
    scan_end "2015-07-16 18:41:51"
    order_item_id 1
    is_invalid false
  end
end
