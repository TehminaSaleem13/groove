# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :shipstation_credential, :class => 'ShipstationCredential' do

    username "MyString"
    password "MyString"
  end
end
