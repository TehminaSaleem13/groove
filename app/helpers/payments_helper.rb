module PaymentsHelper
  def card_list(current_tenant)
    create_result_hash
    @result['cards'] = []
    customer = get_current_customer(current_tenant)
    @result['cards'] = customer.cards unless customer.nil? || customer.cards.nil?
  end

  def add_card(card_info, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    unless customer.nil?
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
  end

  def make_default_card(card, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    unless customer.nil?
      customer.default_card = card
      customer.save
    end
  end

  def get_default_card(current_tenant)
    create_result_hash
    @result['default_card'] = nil
    customer = get_current_customer(current_tenant)
    @result['default_card'] = customer.default_card unless customer.nil? || customer.default_card.nil?
  end

  def delete_a_card(card, current_tenant)
    create_result_hash
    customer = get_current_customer(current_tenant)
    customer.cards.retrieve(card).delete() unless customer.nil? || customer.cards.retrieve(card).nil?
  end

  def get_current_customer(current_tenant)
    tenant = Tenant.where(name: current_tenant).first unless Tenant.where(name: current_tenant).first.nil?
    begin
      unless tenant.subscription.nil? || tenant.subscription.stripe_customer_id.nil?
        @customer_info = Stripe::Customer.retrieve(tenant.subscription.stripe_customer_id)
        if (defined?(@customer_info.deleted).nil?)
          return @customer_info
        else
          @result['status'] = false
          @result['messages'].push("This customer account has been permanently closed.")
          return nil
        end
      else
        @result['status'] = false
        @result['messages'].push("You don't have a valid customer id")
        return nil
      end
    rescue Stripe::InvalidRequestError => er
      @result['status'] = false
      @result['messages'].push(er.message)
      return nil
    end
  end

  def delete_customer(customer_id)
    customer = Stripe::Customer.retrieve(customer_id)
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
      @result['messages'].push(e.message);
    end
  end

  def get_next_payment_date(subscription)
    create_result_hash
    @result['next_date'] = nil
    unless subscription.nil? || subscription.stripe_customer_id.nil?
      customer = Stripe::Customer.retrieve(subscription.stripe_customer_id)
      @result['next_date'] = (Time.at(customer.subscriptions.data.first.current_period_end).to_datetime).strftime "%B %d %Y" unless customer.subscriptions.data.empty?
    end
    @result
  end

  def calculate_discount_amount(coupon_id)
    create_result_hash
    @result['percent_off'] = 0
    coupons = Stripe::Coupon.all(limit: 30)
    valid = false
    @result['discount_amount'] = 0
    coupons.each do |coupon|
      if coupon.id == coupon_id
        valid = true
        if coupon.percent_off
          @result['discount_amount'] = (ENV['ONE_TIME_PAYMENT'].to_i * coupon.percent_off) / 100
        elsif coupon.amount_off
          @result['discount_amount'] = coupon.amount_off
        end
        break
      end
    end
    unless valid
      @result['status'] = false
      @result['messages'].push('Oops! promotional code is not valid. You can still proceed with submitting the form.')
    else
      @result['messages'].push('Congrats! Your promotional code is valid.')
    end
    @result
  end

  def update_subcription_plan(subscription, plan_id)
    customer = Stripe::Customer.retrieve(subscription.stripe_customer_id)
    customer_subscription = customer.subscriptions.retrieve(subscription.customer_subscription_id)
    customer_subscription.plan = plan_id
    customer_subscription.save
  end

  def get_plan_id(plan_name)
    case plan_name
    when 'solo'
      return 'groove-solo'
    when 'duo'
      return 'groove-duo'
    when 'trio'
      return 'groove-trio'
    when 'quintet'
      return 'groove-quintet'
    when 'symphony'
      return 'groove-symphony'
    when 'annual-solo'
      return 'annual-groove-solo'
    when 'annual-duo'
      return 'annual-groove-duo'
    when 'annual-trio'
      return 'annual-groove-trio'
    when 'annual-quintet'
      return 'annual-groove-quintet'
    when 'annual-symphony'
      return 'annual-groove-symphony'
    end
  end
end
