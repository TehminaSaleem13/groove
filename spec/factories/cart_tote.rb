FactoryBot.define do
  factory :cart_tote do
    sequence(:tote_id) { |n| "tote-#{n}" }
    width { 10.0 }
    height { 8.0 }
    weight { 2.0 }
    cart_row
  end
end