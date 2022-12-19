# frozen_string_literal: true

FactoryBot.define do
  factory :event_log do
    data { '' }
    message { 'MyText' }
    user_id { 1 }
  end
end
