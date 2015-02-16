module PaymentsHelper
	def card_list(current_tenant)
    customer = get_current_customer(current_tenant)
    @cards = customer.cards
  end

  def add_card(card_info, current_tenant)
  	@result = Hash.new
  	@result['status'] = true
  	@result['messages'] = []
    customer = get_current_customer(current_tenant)
    puts "1"
    begin
    	token = Stripe::Token.create(
	      card: {
	        number: card_info[:last4],
	        exp_month: card_info[:exp_month],
	        exp_year: card_info[:exp_year],
	        cvc: card_info[:cvc]
	      }
	    ) 
	    card = customer.cards.create(card: token.id)
	    if card.save
		    customer.default_card = card.id
		    customer.save
		  else
		  	@result['status'] = false
		  	@result['messages'].push("The card could not be created because of server problem")
		  end
		rescue Stripe::CardError => e
    	@result['status'] = false
    	@result['messages'].push(e.message)
    rescue Stripe::InvalidRequestError => er
    	@result['status'] = false
    	@result['messages'].push(er.message)
    end
  end

  def make_default_card(card, current_tenant)
    customer = get_current_customer(current_tenant)
    customer.default_card = card
    customer.save
  end

  def get_default_card(current_tenant)
    customer = get_current_customer(current_tenant)
    customer.default_card
  end

  def delete_a_card(card, current_tenant)
    customer = get_current_customer(current_tenant)
    customer.cards.retrieve(card).delete()
  end

  def get_current_customer(current_tenant)
    tenant = Tenant.where(name: current_tenant).first unless Tenant.where(name: current_tenant).first.nil?
    Stripe::Customer.retrieve(tenant.subscription.stripe_customer_id) 
  end
end