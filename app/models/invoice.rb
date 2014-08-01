class Invoice < ActiveRecord::Base
  attr_accessible :date, :invoice_id, :subscription_id, :amount, :period_start, :period_end, :quantity, :plan_id, :customer_id, :charge_id, :attempted, :closed, :forgiven, :paid
end
