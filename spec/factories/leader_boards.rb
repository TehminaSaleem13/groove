# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :leader_board do
    scan_time { '2015-07-04 15:46:03' }
    order_id { 1 }
    order_item_count { 1 }
  end
end
