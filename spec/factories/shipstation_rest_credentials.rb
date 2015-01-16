# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :shipstation_rest_credential, :class => 'ShipstationRestCredential' do

    api_key "MyString"
    api_secret "MyString"
  end
end
