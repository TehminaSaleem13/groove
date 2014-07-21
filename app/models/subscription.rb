class Subscription < ActiveRecord::Base
  attr_accessible :card_code, :card_month, :card_number, :card_year, 
    :email, :stripe_customer_token
  # validates_presence_of :email
  # validates_presence_of :card_number
  # validates_presence_of :card_code
  # validates_presence_of :card_month
  # validates_presence_of :card_year
  attr_accessor :stripe_card_token
  def save_with_payment
  	if valid?
  		customer = Stripe::Customer.create(description: email)
  		self.stripe_customer_token = customer.id
      puts "inspect:" + self.inspect
      begin
        puts ".............."
        Stripe::Charge.create(
          :amount => 1000,
          :currency => "usd",
          :customer => self.stripe_customer_token,
          :description => email
        )
        puts "//////////////"
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
