# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
  	email "test@groovepacker.com"
    username "admin"
    password "12345678" 
    password_confirmation "12345678"
    import_orders "0"
  end
end
