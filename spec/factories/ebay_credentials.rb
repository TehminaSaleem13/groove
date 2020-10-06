# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :ebay_credential, :class => 'EbayCredentials' do
    # dev_id "MyString"
    # app_id "MyString"
    # cert_id "MyString"
    auth_token {"MyString"}
  end
end
