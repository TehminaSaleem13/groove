# frozen_string_literal: true

module PaymentsHelper
  def card_list(current_tenant)
    create_result_hash
    @result['cards'] = []
    customer = get_current_customer(current_tenant)
    @result['cards'] = Stripe::Customer.list_sources(customer.id, object: 'card') if customer
  end

  def add_card(card_info, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    return unless customer

    begin
      token = create_token(card_info)
      card = Stripe::Customer.create_source(customer.id, { source: token.id })
      if card.cvc_check
        if Stripe::Customer.update_source(customer.id, card.id)
          # customer.default_card = card.id
          Stripe::Customer.update(customer.id)
        else
          update_result_fail('The card could not be created because of server problem')
        end
      else
        card.delete
        update_result_fail('The CVC entered is not correct. Modify it.')
      end
    rescue Stripe::CardError => e
      update_result_fail(e.message)
    rescue Stripe::InvalidRequestError => e
      update_result_fail(e.message)
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
    @result['default_card'] = customer.default_source if customer&.default_source
  end

  def delete_a_card(card, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    card = Stripe::Customer.retrieve_source(customer.id, card)
    card.delete if card
  end

  def get_current_customer(current_tenant)
    @tenant = Tenant.where(name: current_tenant).first
    return unless @tenant

    begin
      subscription = @tenant.subscription
      return nil if subscription.nil? || subscription.stripe_customer_id.nil?

      @customer_info = get_stripe_customer(subscription.stripe_customer_id)
      if defined?(@customer_info.deleted).nil?
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
    rescue Stripe::InvalidRequestError => e
      update_result_fail(e.message)
      return nil
    end
  end

  def delete_customer(customer_id)
    customer = get_stripe_customer(customer_id)
    if defined?(customer.deleted).nil?
      # customer.delete()
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
    if subscription&.stripe_customer_id
      customer = get_stripe_customer(subscription.stripe_customer_id)
      stripe_subscription = Stripe::Subscription.list(customer:).first
      @result['next_date'] = Time.at(stripe_subscription.current_period_end).to_datetime.strftime '%B %d %Y' if stripe_subscription
    end
    @result
  end

  def calculate_discount_amount(coupon_id)
    create_result_hash
    coupons = Stripe::Coupon.list(limit: 30)
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
    customer_subscription = Stripe::Subscription.retrieve(subscription.customer_subscription_id)
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
      'Groove 100' => 'groove-100',
      'Groove 150' => 'groove-150',
      'Groove 200' => 'groove-200',
      'Groove 250' => 'groove-250',
      'Groove 350' => 'groove-350',
      'Groove 500' => 'groove-500',
      'An Groove 100' => 'an-groove-100',
      'An Groove 150' => 'an-groove-150',
      'An Groove 200' => 'an-groove-200',
      'An Groove 250' => 'an-groove-250',
      'An Groove 350' => 'an-groove-350',
      'An Groove 500' => 'an-groove-500'
    }
  end

  def create_plan(amount, interval, name, currency, id, trial_period_days = nil)
    Stripe::Plan.create(
      amount: amount,
      interval: interval,
      nickname: name,
      currency: currency,
      product: {
        name: id
      },
      trial_period_days: trial_period_days
    )
  end

  def get_plan_name(plan_id)
    Stripe::Plan.retrieve(plan_id).name
  rescue StandardError
    ''
  end

  def get_stripe_customer(customer_id)
    Stripe::Customer.retrieve(customer_id)
  end

  def get_subscription(customer_id, subscription_id)
    @customer = get_stripe_customer(customer_id)
    return Stripe::Subscription.retrieve(subscription_id) if @customer
  end
end
