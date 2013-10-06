# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_barcode do
    product nil
    barcode "MyString"
  end
end
