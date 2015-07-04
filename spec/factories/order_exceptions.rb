# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_exception, :class => 'OrderException' do
    reason "MyString"
    description "MyString"
    user nil
  end
end
