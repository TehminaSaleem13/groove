FactoryGirl.define do
  factory :subscription do
    email "success@simulator.amazonses.com"
    tenant_name 'test'
    amount '30'
    stripe_user_token 'fsafa43244324234'
    status nil
    tenant_id nil
    stripe_transaction_identifier nil
    transaction_errors nil
    subscription_plan_id nil
    customer_subscription_id nil
    stripe_customer_id nil
    is_active false
    password '12345678'
    user_name 'test_user'
    coupon_id 'trt435'
    progress nil
  end
end
