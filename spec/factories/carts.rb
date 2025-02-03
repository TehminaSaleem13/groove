FactoryBot.define do
  factory :cart do
    sequence(:cart_name) { |n| "Cart #{n}" }
    sequence(:cart_id) { |n| "C#{n.to_s.rjust(2, '0')}" }
    number_of_totes { 5 }
  end
end

FactoryBot.define do
  factory :cart_row do
    sequence(:row_name) { |n| ('A'..'Z').to_a[n % 26] }
    row_count { 5 }
    cart
  end
end
