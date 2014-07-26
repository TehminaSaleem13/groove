class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_user_token, :tenant_name, :amount
  belongs_to :tenant
  validates_presence_of :email
  validates_presence_of :tenant_name
  # validates_uniqueness_of :tenant_name
  

  def save_with_payment
    puts "save with payment"
  	if valid?
      begin
        Stripe::Charge.create(
          :amount => self.amount.to_i*100,
          :currency => "usd",
          :card => stripe_user_token,
          :description => self.email
        )
        transactions = Stripe::BalanceTransaction.all
        self.stripe_transaction_identifier = transactions.first.id
        CreateTenant.delay(:run_at => 1.seconds.from_now).create_tenant self
        # CreateTenant.create_tenant self
        Apartment::Tenant.switch()

      rescue Stripe::CardError => e
        # The card has been declined
        self.status = 'failed'
        self.save
        puts "Card declined"
        puts e.inspect
      end
      self.status = 'completed'
      self.save

  		save!
  	end
  rescue Stripe::InvalidRequestError => e
    self.status = 'failed'
    self.save
  	logger.error "Stripe error while creating customer: #{e.message}"
  	errors.add :base, "There was a problem with your credit card."
  	false
  end
end
