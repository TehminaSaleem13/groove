# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :product_barcode do
    product {nil}
    barcode {"1234567890"}
  end
end
