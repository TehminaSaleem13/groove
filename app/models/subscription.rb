class Subscription < ActiveRecord::Base
  attr_accessible :card_code, :card_month, :card_number, :card_year, :email, :stripe_customer_token
end
