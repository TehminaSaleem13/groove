# frozen_string_literal: true

module PaymentsHelper
  def card_bank_list(current_tenant)
    create_result_hash
    @result['cards'] = []
    @result['bank_accounts'] = []
    customer = get_current_customer(current_tenant)
    @result['cards'] = Stripe::PaymentMethod.list(customer: customer.id, type: 'card') if customer
    @result['bank_accounts'] = Stripe::PaymentMethod.list(customer: customer.id, type: 'us_bank_account') if customer
  end

  def add_card_bank_details(info, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    return unless customer

    begin
      token = info["type"] == "bank" ? create_bank_account_token(info) : create_token(info)
      source = Stripe::Customer.create_source(customer.id, { source: token.id })
      info["type"] == "bank" ? bank_details(source, customer) : card_details(source, customer)
    rescue Stripe::CardError => e
      update_result_fail(e.message)
    rescue Stripe::InvalidRequestError => e
      update_result_fail(e.message)
    rescue Stripe::StripeError => e
      update_result_fail(e.message)
    rescue StandardError => e
      update_result_fail("An unexpected error occurred: #{e.message}")
    end
  end

  def card_details(source, customer)
    if source.cvc_check
      if Stripe::Customer.update_source(customer.id, source.id)
        Stripe::Customer.update(customer.id)
      else
        update_result_fail('The card could not be created because of server problem')
      end
    else
      source.delete
      update_result_fail('The CVC entered is not correct. Modify it.')
    end
  end

  def bank_details(source, customer)
    source.verify(amounts: [32, 45])
    if source.status == 'verified' || source.status == 'new'
      Stripe::Customer.update(customer.id, default_source: source.id)
    else
      source.delete
      update_result_fail('The bank account could not be verified. Please check the details.')
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

  def create_bank_account_token(bank_info)
    Stripe::Token.create(
      bank_account: {
        account_holder_name: bank_info[:account_holder_name],
        account_holder_type: bank_info[:account_holder_type],
        routing_number: bank_info[:routing_number],
        account_number: bank_info[:last4],
        country: bank_info[:country]
      }
    )
  end


  def make_default_card(card, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    if customer
      customer.invoice_settings.default_payment_method = card
      customer.save
    end
  end

  def get_default_card(current_tenant)
    create_result_hash
    @result['default_card'] = nil
    customer = get_current_customer(current_tenant)
    @result['default_card'] = customer&.invoice_settings&.default_payment_method || customer&.default_source
  end

  def delete_a_card(card, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    retrieved_card = Stripe::PaymentMethod.retrieve(card)
    Stripe::PaymentMethod.detach(card) if retrieved_card&.customer == customer.id
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
