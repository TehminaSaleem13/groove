# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :shipstation_rest_credential, :class => 'ShipstationRestCredential' do

    api_key "45893449eae24f2e8bc7992904016ca6"
    api_secret "ddefa497b0fc48c0b162a533920ce990"
  end
end
