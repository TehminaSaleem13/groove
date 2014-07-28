class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_user_token, :tenant_name, :amount, :transaction_errors
  belongs_to :tenant
  

  def save_with_payment
  	if valid?
      begin
        customer = Stripe::Customer.create(
          :card => self.stripe_user_token,
          :description => self.email,
          :plan => "02"
        )
        puts "customer:" + customer.inspect
        subscription = customer.subscriptions.create(:plan => "02")
        puts "subscription" + subscription.inspect

        # Stripe::Charge.create(
        #   # :amount => self.amount*100,
        #   :currency => "usd",
        #   :customer => customer.id,
        #   :description => self.email
        # )
        transactions = Stripe::BalanceTransaction.all
        self.stripe_transaction_identifier = transactions.first.id
        CreateTenant.delay(:run_at => 1.seconds.from_now).create_tenant self
        # CreateTenant.create_tenant self
        Apartment::Tenant.switch()

      rescue Stripe::CardError => e
        self.status = 'failed'
        self.save
        self.transaction_errors = e.message
      end
      self.status = 'completed'
      self.save

  		save!
  	end
  rescue Stripe::InvalidRequestError => e
    self.status = 'failed'
    self.transaction_errors = e.message
    self.save
  	logger.error "Stripe error while creating customer: #{e.message}"
  	errors.add :base, "There was a problem with your credit card."
  	false
  end
end
