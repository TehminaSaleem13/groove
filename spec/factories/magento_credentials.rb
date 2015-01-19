# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :magento_credential, :class => 'MagentoCredentials' do
    host "http://www.groovepacker.com/store"
    username "gpacker"
    password "gpaker"
    api_key "gpacker"
  end
end
