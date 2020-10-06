# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :product_image do
    product {nil}
    image {"MyString"}
  end
end
