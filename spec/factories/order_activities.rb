# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_activity, class: 'OrderActivities' do
    activitytime { '2013-11-05 20:28:35' }
    order { nil }
    user { nil }
    action { 'MyString' }
  end
end
