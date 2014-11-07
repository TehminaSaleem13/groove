# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :csv_product_import do
    status "MyString"
    current 1
    total 1
    current_sku "MyString"
  end
end
