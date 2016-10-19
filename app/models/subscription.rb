class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_user_token, :tenant_name, :amount, :transaction_errors, 
                  :subscription_plan_id, :status, :user_name, :password, :coupon_id,
                  :stripe_customer_id, :is_active, :tenant_id, :stripe_transaction_identifier,
                  :progress, :customer_subscription_id, :created_at, :updated_at
  belongs_to :tenant
  has_many :transactions
  include PaymentsHelper

  after_create :add_subscriber_to_campaignmonitor
  before_save :check_value_of_customer_subscription

  
  def check_value_of_customer_subscription
    self.customer_subscription_id = self.changes.values[0][0] if [nil, "", "null", "undefined"].include?(self.customer_subscription_id)
  end
  def save_with_payment(one_time_payment)
    begin
      if valid?
        if self.coupon_id
          Apartment::Tenant.switch()
          one_time_payment = calculate_otp(self.coupon_id, one_time_payment.to_i)
        end
        create_subscribed_plan_if_not_exist
        customer = create_customer(one_time_payment)

        if customer
          self.update_progress('customer_created')
          self.stripe_customer_id = customer.id
          create_tenant_and_transaction(customer)
        end
        self.status = 'completed'
        self.is_active = true
        self.save
      end
    rescue Stripe::CardError => e
      update_status_and_send_email(e)
      # logger.error "There was an error with Stripe: #{e.message}"
      false
    rescue Stripe::InvalidRequestError => e
      update_status_and_send_email(e)
      # logger.error "Stripe error while creating customer: #{e.message}"
      # errors.add :base, "There was a problem with your credit card."
      false
    rescue Exception => e
      update_status_and_send_email(e)
      # logger.error "There was a problem with subscription process #{e.message}"
      false
    end
  end

  def create_subscribed_plan_if_not_exist
    interval = self.subscription_plan_id.split("-").first=="an" ? "year" : "month"
    currency = 'usd'
    subsc_amount = self.amount.to_i
    name = self.subscription_plan_id.titleize
    subsc_plan_id = self.subscription_plan_id
    begin
      create_plan(subsc_amount, interval, name, currency, subsc_plan_id, 30)
    rescue Stripe::InvalidRequestError => e

    end
  end

  def update_progress(progress)
    self.progress = progress
    self.save
  end

  def calculate_otp(coupon_id, one_time_payment)
    coupon_data = Stripe::Coupon.retrieve(coupon_id)
    @coupon = Coupon.where(coupon_id: coupon_data.id).first
    status = true
    if @coupon
      status = check_status(@coupon)
    else
      @coupon = create_coupon(coupon_data)
    end

    if status
      @coupon.times_redeemed += 1
      result = calculate_discount_amount(coupon_data.id)
      one_time_payment -= result['discount_amount']
    else
      @coupon.is_valid = false
    end
    @coupon.save
    one_time_payment
  end

  def check_status(coupon)
    status = coupon.is_valid
    if coupon.max_redemptions
      status &= coupon.max_redemptions > coupon.times_redeemed
    end
    status
  end

  def create_tenant_and_transaction(customer)
    return unless customer.subscriptions.data.first
    self.customer_subscription_id = customer.subscriptions.data.first.id

    CreateTenant.new.create_tenant self

    Apartment::Tenant.switch()
    create_transaction(customer)
    self.update_progress('transaction_complete')
  end

  def create_customer(one_time_payment)
    customer = Stripe::Customer.create(
      card: self.stripe_user_token,
      email: self.email,
      plan: self.subscription_plan_id,
      account_balance: one_time_payment
    )
    customer
  end

  def create_transaction(customer)
    transactions = Stripe::BalanceTransaction.all(:limit => 1)
    @transaction = transactions.first
    if @transaction
      self.stripe_transaction_identifier = @transaction.id
      @card_data = customer.cards.data.first
      if @card_data
        Transaction.create(
          transaction_id: @transaction.id,
          amount: self.amount,
          card_type: @card_data.brand,
          exp_month_of_card: @card_data.exp_month,
          exp_year_of_card: @card_data.exp_year,
          date_of_payment: Date.today,
          subscription_id: self.id)
      end
    end
  end

  def create_coupon(coupon_data)
    coupon = Coupon.create(
      coupon_id: coupon_data.id,
      percent_off: coupon_data.percent_off,
      amount_off: coupon_data.amount_off,
      duration: coupon_data.duration,
      redeem_by: coupon_data.redeem_by,
      max_redemptions: coupon_data.max_redemptions,
      times_redeemed: coupon_data.times_redeemed,
      is_valid: coupon_data.valid)
    coupon
  end

  def update_status_and_send_email(e)
    self.status = 'failed'
    self.transaction_errors = e.message
    self.save
    TransactionEmail.failed_subscription(self, e).deliver
  end

  def get_progress_errors
    case progress
    when 'not_started'
      "There was an error adding you as a customer."
    when "customer_created"
      "You have been added as a customer but we were unable to create an account." \
      " an error creating your account. We will continue to try but if you do not " \
      " receive an email at the provided address in 10 minutes please contact" \
      " support@groovepacker.com so we can provide your account details and setup" \
      " information."
    when 'tenant_created'
      "Your account has been created but we were unable to email you at the address given." \
      " We will continue to try but if you do not receive it in 10 minutes please contact" \
      " support@groovepacker.com so we can provide your account details and setup" \
      " information."
    else
      ''
    end
  end

  def add_subscriber_to_campaignmonitor
    initialize_campaingmonitor.add_subscriber_to_lists
  end

  def initialize_campaingmonitor
    @cm ||= Groovepacker::CampaignMonitor::CampaignMonitor.new(subscriber: self)
  end

end
