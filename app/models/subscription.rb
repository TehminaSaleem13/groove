class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_customer_token, :user_name, :password, :password_confirmation, :amount
  belongs_to :tenant
  validates_presence_of :email
  validates_presence_of :user_name
  # validates_uniqueness_of :user_name
  validates_presence_of :password
  validates_presence_of :password_confirmation
  validates_confirmation_of :password_confirmation
  

  def save_with_payment
    puts "save with payment"
  	if valid?
  		# customer = Stripe::Customer.create(description: email, card: stripe_card_token)
  		# self.stripe_customer_token = customer.id
      #   puts "inspect:" + self.inspect
      #   puts "customer:" + customer.inspect
      begin
        Stripe::Charge.create(
          :amount => self.amount.to_i*100,
          :currency => "usd",
          :card => stripe_customer_token,
          # :customer => self.stripe_customer_token,
          :description => self.email
        )
        # if Apartment::Tenant.create(self.user_name)
        #   puts "Tenant created:" + self.user_name
        # end
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

  attr_accessor :stripe_card_token
end
