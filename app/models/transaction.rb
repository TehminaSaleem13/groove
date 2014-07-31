class Transaction < ActiveRecord::Base
  attr_accessible :transaction_id, :amount, :card_type, :exp_month_of_card, :exp_year_of_card, :date_of_payment, :subscription_id

  belongs_to :subscription
end
