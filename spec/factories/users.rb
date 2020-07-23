# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
    username {"admin"}
    password {"12345678"}
    password_confirmation {"12345678"}
    confirmation_code { rand(10 ** 10).to_s }
    active {true}
  end
end
