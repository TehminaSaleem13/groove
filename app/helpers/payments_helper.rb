module PaymentsHelper
  def card_list(current_tenant)
    create_result_hash
    @result['cards'] = []
    customer = get_current_customer(current_tenant)
    @result['cards'] = customer.cards if customer && customer.cards
  end

  def add_card(card_info, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    return unless customer
    begin
      token = create_token(card_info)
      card = customer.cards.create(card: token.id)
      if card.cvc_check
        if card.save
          # customer.default_card = card.id
          customer.save
        else
          update_result_fail('The card could not be created because of server problem')
        end
      else
        card.delete()
        update_result_fail('The CVC entered is not correct. Modify it.')
      end
    rescue Stripe::CardError => e
      update_result_fail(e.message)
    rescue Stripe::InvalidRequestError => er
      update_result_fail(er.message)
    end
  end

  def create_token(card_info)
    token = Stripe::Token.create(
      card: {
        number: card_info[:last4],
        exp_month: card_info[:exp_month],
        exp_year: card_info[:exp_year],
        cvc: card_info[:cvc]
      }
    )
    token
  end

  def make_default_card(card, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    if customer
      customer.default_card = card
      customer.save
    end
  end

  def get_default_card(current_tenant)
    create_result_hash
    @result['default_card'] = nil
    customer = get_current_customer(current_tenant)
    @result['default_card'] = customer.default_card if customer && customer.default_card
  end

  def delete_a_card(card, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    customer.cards.retrieve(card).delete() if customer && customer.cards.retrieve(card)
  end

  def get_current_customer(current_tenant)
    @tenant = Tenant.where(name: current_tenant).first
    return unless @tenant
    begin
      subscription = @tenant.subscription
      return nil if subscription.nil? || subscription.stripe_customer_id.nil?
      @customer_info = get_stripe_customer(subscription.stripe_customer_id)
      if (defined?(@customer_info.deleted).nil?)
        return @customer_info
      else
        update_result_fail('This customer account has been permanently closed.')
        return nil
      end
      # else
      #   # update_result_fail('You don\'t have a valid customer id')
      #   # @result['status'] = false
      #   # @result['messages'].push("You don't have a valid customer id")
      #   return nil
      # end
    rescue Stripe::InvalidRequestError => er
      update_result_fail(er.message)
      return nil
    end
  end

  def delete_customer(customer_id)
    customer = get_stripe_customer(customer_id)
    if (defined?(customer.deleted).nil?)
      customer.delete()
    end
  end

  def create_result_hash
    @result = {}
    @result['status'] = true
    @result['messages'] = []
  end

  def get_plan_info(plan_id)
    create_result_hash
    @result['plan_info'] = nil
    begin
      @result['plan_info'] = Stripe::Plan.retrieve(plan_id)
    rescue Stripe::InvalidRequestError => e
      @result['status'] = false
      @result['messages'].push(e.message)
    end
    @result
  end

  def get_next_payment_date(subscription)
    create_result_hash
    @result['next_date'] = nil
    if subscription && subscription.stripe_customer_id
      customer = get_stripe_customer(subscription.stripe_customer_id)
      subscriptions_data = customer.subscriptions.data
      @result['next_date'] = (Time.at(subscriptions_data.first.current_period_end).to_datetime).strftime "%B %d %Y" unless subscriptions_data.empty?
    end
    @result
  end

  def calculate_discount_amount(coupon_id)
    create_result_hash
    coupons = Stripe::Coupon.all(limit: 30)
    valid = false
    @result['discount_amount'] = 0
    coupons.each do |coupon|
      next if coupon.id != coupon_id
      valid = true
      if coupon.percent_off
        @result['discount_amount'] = (ENV['ONE_TIME_PAYMENT'].to_i * coupon.percent_off) / 100
      elsif coupon.amount_off
        @result['discount_amount'] = coupon.amount_off
      end
      break
    end
    if valid
      @result['messages'].push('Congrats! Your promotional code is valid.')
    else
      update_result_fail('Oops! promotional code is not valid. You can still proceed with submitting the form.')
    end
    @result
  end

  def update_subcription_plan(subscription, plan_id)
    customer = get_stripe_customer(subscription.stripe_customer_id)
    customer_subscription = customer.subscriptions.retrieve(subscription.customer_subscription_id)
    customer_subscription.plan = plan_id
    customer_subscription.save
  end

  def update_result_fail(message)
    @result['status'] = false
    @result['messages'].push(message)
  end

  def get_plan_id(plan_name)
    construct_plan_hash[plan_name]
  end

  def construct_plan_hash
    {
      'solo' => 'groove-solo',
      'duo' => 'groove-duo',
      'trio' => 'groove-trio',
      'quintet' => 'groove-quintet',
      'symphony' => 'groove-symphony',
      'annual-solo' => 'annual-groove-solo',
      'annual-duo' => 'annual-groove-duo',
      'annual-trio' => 'annual-groove-trio',
      'annual-quintet' => 'annual-groove-quintet',
      'annual-symphony' => 'annual-groove-symphony',
      'duo-60' => 'groove-duo-60',
      'trio-90' => 'groove-trio-90',
      'quartet-120' => 'groove-quartet-120',
      'quintet-150' => 'groove-quintet-150',
      'bigband-210' => 'groove-bigband-210',
      'symphony-300' => 'groove-symphony-300',
      'an-duo' => 'an-groove-duo',
      'an-trio' => 'an-groove-trio',
      'an-quartet' => 'an-groove-quartet',
      'an-quintet' => 'an-groove-quintet',
      'an-bigband' => 'an-groove-bigband',
      'an-symphony' => 'an-groove-symphony'
    }
  end

  def create_plan(amount, interval, name, currency, id)
    Stripe::Plan.create(
      amount: amount,
      interval: interval,
      name: name,
      currency: currency,
      id: id
    )
  end

  def get_plan_name(plan_id)
    Stripe::Plan.retrieve(plan_id).name
  end

  def get_stripe_customer(customer_id)
    Stripe::Customer.retrieve(customer_id)
  end

  def get_subscription(customer_id, subscription_id)
    customer = get_stripe_customer(customer_id)
    return customer.subscriptions.retrieve(subscription_id)
  end
end
