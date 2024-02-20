FactoryBot.define do
  factory :shopline_credential do
    shop_name { ENV['SHOPLINE_SAMPLE_SHOP_NAME'] }
    access_token { ENV['SHOPLINE_SAMPLE_SHOP_ACCESS_KEY'] }
  end
end
