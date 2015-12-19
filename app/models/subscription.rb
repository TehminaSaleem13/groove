class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_user_token, :tenant_name, :amount, :transaction_errors, 
                  :subscription_plan_id, :status, :user_name, :password, :coupon_id,
                  :stripe_customer_id, :is_active, :tenant_id, :stripe_transaction_identifier,
                  :progress, :customer_subscription_id, :created_at, :updated_at
  belongs_to :tenant
  has_many :transactions
  include PaymentsHelper

  def save_with_payment(one_time_payment)
    begin
      if valid?
        unless self.coupon_id.nil?
          coupon_data = Stripe::Coupon.retrieve(self.coupon_id)
          Apartment::Tenant.switch()
          coupon = Coupon.where(
            :coupon_id => coupon_data.id).first unless Coupon.where(:coupon_id => coupon_data.id).empty?
          unless coupon.nil? || coupon.max_redemptions == coupon.times_redeemed || coupon.is_valid == false
            coupon.times_redeemed += 1
            coupon.save
          else
            coupon = Coupon.create(coupon_id: coupon_data.id,
                                   percent_off: coupon_data.percent_off,
                                   amount_off: coupon_data.amount_off,
                                   duration: coupon_data.duration,
                                   redeem_by: coupon_data.redeem_by,
                                   max_redemptions: coupon_data.max_redemptions,
                                   times_redeemed: coupon_data.times_redeemed,
                                   is_valid: coupon_data.valid)
          end
          result = calculate_discount_amount(coupon_data.id)
          one_time_payment = one_time_payment.to_i - result['discount_amount']
        end

        customer = Stripe::Customer.create(
          :card => self.stripe_user_token,
          :email => self.email,
          :plan => self.subscription_plan_id,
          :account_balance => one_time_payment
        )

        unless customer.nil?
          self.update_progress('customer_created')
          self.stripe_customer_id = customer.id

          unless customer.subscriptions.data.first.nil?
            self.customer_subscription_id = customer.subscriptions.data.first.id

            CreateTenant.new.create_tenant self

            Apartment::Tenant.switch()

            transactions = Stripe::BalanceTransaction.all(:limit => 1)
            unless transactions.first.nil?
              self.stripe_transaction_identifier = transactions.first.id
              unless customer.cards.data.first.nil?
                card_type = customer.cards.data.first.brand
                exp_month_of_card = customer.cards.data.first.exp_month
                exp_year_of_card = customer.cards.data.first.exp_year
                transaction = Transaction.create(
                  transaction_id: transactions.first.id,
                  amount: self.amount,
                  card_type: card_type,
                  exp_month_of_card: exp_month_of_card,
                  exp_year_of_card: exp_year_of_card,
                  date_of_payment: Date.today(),
                  subscription_id: self.id)
              end
            end
            self.update_progress('transaction_complete')
          end
        end
        self.status = 'completed'
        self.is_active = true
        self.save
      end
    rescue Stripe::CardError => e
      self.status = 'failed'
      self.transaction_errors = e.message
      self.save
      logger.error "There was an error with Stripe: #{e.message}"
      false
    rescue Stripe::InvalidRequestError => e
      self.status = 'failed'
      self.transaction_errors = e.message
      self.save
      logger.error "Stripe error while creating customer: #{e.message}"
      errors.add :base, "There was a problem with your credit card."
      false
    rescue Exception => e
      self.status = 'failed'
      self.transaction_errors = e.message
      self.save
      logger.error "There was a problem with subscription process #{e.message}"
      false
    end
  end

  # Progress will be: "customer_created", "tenant_created",
  # "email_sent"
  def update_progress(progress)
    self.progress = progress
    self.save
  end

  def get_progress_errors
    if progress == "not_started"
      "There was an error adding you as a customer."
    elsif progress == "customer_created"
      "You have been added as a customer but we were unable to create an account."+
        " an error creating your account. We will continue to try but if you do not "+
        " receive an email at the provided address in 10 minutes please contact" +
        " support@groovepacker.com so we can provide your account details and setup" +
        " information."
    elsif progress == "tenant_created"
      "Your account has been created but we were unable to email you at the address given." +
        " We will continue to try but if you do not receive it in 10 minutes please contact" +
        " support@groovepacker.com so we can provide your account details and setup" +
        " information."
    else
      ""
    end
  end

end
