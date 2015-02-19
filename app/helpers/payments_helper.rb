module PaymentsHelper
	def card_list(current_tenant)
		create_result_hash
		@result['cards'] = []
    customer = get_current_customer(current_tenant)
    unless customer.nil?
    	@result['cards'] = customer.cards 
    else
    	@result['status'] = false
    end
  end

  def add_card(card_info, current_tenant)
  	create_result_hash
    customer = get_current_customer(current_tenant)
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
	    unless card.cvc_check.nil?
		    if card.save
			    # customer.default_card = card.id
			    customer.save
			  else
			  	@result['status'] = false
			  	@result['messages'].push("The card could not be created because of server problem")
			  end
			else
				card.delete();
				@result['status'] = false
				@result['messages'].push("The CVC entered is not correct. Modify it.")
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
  	create_result_hash
    customer = get_current_customer(current_tenant)
    unless customer.nil?
	    customer.default_card = card
	    customer.save
	  else
	  	@result['status'] = false
	  end
  end

  def get_default_card(current_tenant)
  	create_result_hash
  	@result['default_card'] = nil
    customer = get_current_customer(current_tenant)
    unless customer.nil?
    	@result['default_card'] = customer.default_card 
    else
    	@result['status'] = false
    end
  end

  def delete_a_card(card, current_tenant)
  	create_result_hash
    customer = get_current_customer(current_tenant)
    unless customer.nil?
    	customer.cards.retrieve(card).delete()
    else
    	@result['status'] = false
    end 
  end

  def get_current_customer(current_tenant)
    tenant = Tenant.where(name: current_tenant).first unless Tenant.where(name: current_tenant).first.nil?
    begin
    	Stripe::Customer.retrieve(tenant.subscription.stripe_customer_id) unless tenant.subscription.stripe_customer_id.nil?
    rescue Stripe::InvalidRequestError => er
    	@result['messages'].push(er.message)
    	return nil
    end
  end

  def create_result_hash
  	@result = Hash.new
  	@result['status'] = true
  	@result['messages'] = []
  end

  def getPlanInfo(plan_id)
    create_result_hash
    @result['plan_info'] = nil
    begin
      @result['plan_info'] = Stripe::Plan.retrieve(plan_id) 
      puts @plan_info.inspect
    rescue Stripe::InvalidRequestError => e
      @result['status'] = false
      @result['messages'].push(e.message);
    end
  end
end