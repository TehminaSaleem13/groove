class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_user_token, :tenant_name, :amount, :transaction_errors, :subscription_plan_id, :status, :user_name, :password
  belongs_to :tenant
  has_many :transactions
  

  def save_with_payment
  	if valid?
      begin
        customer = Stripe::Customer.create(
          :card => self.stripe_user_token,
          :description => self.email,
          :plan => self.subscription_plan_id
        )
        #whenever you do .first, make sure null check is done
        self.stripe_customer_id = customer.id
        
        unless customer.subscriptions.data.first.nil?
          self.customer_subscription_id = customer.subscriptions.data.first.id
          # Stripe::Charge.create(
          #   # :amount => self.amount*100,
          #   :currency => "usd",
          #   :customer => customer.id,
          #   :description => self.email
          # )
          
          transactions = Stripe::BalanceTransaction.all(:limit => 1)
          unless transactions.first.nil?
            self.stripe_transaction_identifier = transactions.first.id
            # CreateTenant.delay(:run_at => 1.seconds.from_now).create_tenant self
            CreateTenant.create_tenant self
            Apartment::Tenant.switch()
            unless customer.cards.data.first.nil?
              card_type = customer.cards.data.first.brand
              exp_month_of_card = customer.cards.data.first.exp_month
              exp_year_of_card = customer.cards.data.first.exp_year
              transaction = Transaction.create(
                transaction_id: transactions.first.id,
                amount: self.amount,
                card_type: card_type,
                exp_month_of_card: exp_month_of_card,
                exp_year_of_card: exp_year_of_card,
                date_of_payment: Date.today(),
                subscription_id: self.id)
            end
          end
        end

      rescue Stripe::CardError => e
        self.status = 'failed'
        self.save
        self.transaction_errors = e.message
      end
      self.status = 'completed'
      self.is_active = true
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
