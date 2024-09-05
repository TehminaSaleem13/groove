# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :product do
    store_product_id { 'IPHONE456' }
    name { "Apple iPhone 5S-#{Time.current.to_i}" }
    product_type { 'Smartphone' }
    store_id { 1 }
    status { 'active' }
    is_kit { 0 }
    kit_parsing { nil }

    trait :with_sku_barcode do
      after :create do |product|
        create_list :product_sku, 1, product:, sku: product.name.gsub(/[[:space:]]/, '')
        create_list :product_barcode, 1, product:, barcode: product.name.gsub(/[[:space:]]/, '')
      end
    end
  end
end
