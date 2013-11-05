# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_exception, :class => 'OrderExceptions' do
    reason "MyString"
    description "MyString"
    user nil
  end
end
