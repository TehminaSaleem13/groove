# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :magento_credential, :class => 'MagentoCredentials' do
    host "MyString"
    username "MyString"
    password "MyString"
  end
end
