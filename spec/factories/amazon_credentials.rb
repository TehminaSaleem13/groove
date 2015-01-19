# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :amazon_credential, :class => 'AmazonCredentials' do
    # access_key_id "MyString"
    # secret_access_key "MyString"
    # app_name "MyString"
    # app_version "MyString"
    merchant_id "AZPAOT3RJ9YST"
    marketplace_id "ATVPDKIKX0DER"
  end
end
