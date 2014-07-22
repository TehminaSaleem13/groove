class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_customer_token, :user_name, :password, :password_confirmation, :amount
  validates_presence_of :email
  validates_presence_of :user_name
  # validates_uniqueness_of :user_name
  validates_presence_of :password
  validates_presence_of :password_confirmation
  validates_confirmation_of :password_confirmation
  attr_accessor :stripe_card_token
  def save_with_payment
  	if valid?
  		customer = Stripe::Customer.create(description: email)
  		self.stripe_customer_token = customer.id
      puts "inspect:" + self.inspect
      begin
        Stripe::Charge.create(
          :amount => 1000,
          :currency => "usd",
          :customer => self.stripe_customer_token,
          :description => email
        )
      rescue Stripe::CardError => e
        # The card has been declined
        puts "Card declined"
        puts e.inspect
      end
  		save!
  	end
  rescue Stripe::InvalidRequestError => e
  	logger.error "Stripe error while creating customer: #{e.message}"
  	errors.add :base, "There was a problem with your credit card."
  	false
  end
end
