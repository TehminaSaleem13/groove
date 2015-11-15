# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :sync_option do
    product_id 1
    sync_with_bc false
    bc_product_id 1
  end
end
