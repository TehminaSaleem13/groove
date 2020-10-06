# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_exception, :class => 'OrderException' do
    reason {"MyString"}
    description {"MyString"}
    user {nil}
  end
end
