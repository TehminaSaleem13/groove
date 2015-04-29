class Subscription < ActiveRecord::Base
  attr_accessible :email, :stripe_user_token, :tenant_name, :amount, :transaction_errors, :subscription_plan_id, :status, :user_name, :password, :coupon_id
  belongs_to :tenant
  has_many :transactions
  

  def save_with_payment(one_time_payment)
  	if valid?
      begin
        unless self.coupon_id.nil?
          coupon = Stripe::Coupon.retrieve(self.coupon_id)
          Apartment::Tenant.switch()
          # if coupon.valid
          #   unless coupon.max_redemptions.nil? || coupon.times_redeemed >= coupon.max_redemptions
          #     puts "about to update coupon."
          #     coupon.metadata[times_redeemed] = coupon.times_redeemed + 1
          #     one_time_payment = one_time_payment.to_i - ((one_time_payment.to_i * coupon.percent_off) / 100)
          #     coupon.save
          #     puts coupon.inspect
          #   end
          # end
          coupon_data = Stripe::Coupon.retrieve(self.coupon_id)
          coupon = Coupon.where(:coupon_id=>coupon_data.id).first unless Coupon.where(:coupon_id=>coupon_data.id).empty?
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
          one_time_payment = one_time_payment.to_i - ((one_time_payment.to_i * coupon_data.percent_off) / 100)
        end
        if one_time_payment == 0
          customer = Stripe::Customer.create(
          :email => self.email,
          :plan => self.subscription_plan_id,
          :account_balance => one_time_payment
        )
        else
          customer = Stripe::Customer.create(
          :card => self.stripe_user_token,
          :email => self.email,
          :plan => self.subscription_plan_id,
          :account_balance => one_time_payment
        )
        end
        #whenever you do .first, make sure null check is done
        unless customer.nil?
          self.stripe_customer_id = customer.id
        
          unless customer.subscriptions.data.first.nil?
            self.customer_subscription_id = customer.subscriptions.data.first.id
            # Stripe::Charge.create(
            #   # :amount => self.amount*100,
            #   :currency => "usd",
            #   :customer => customer.id,
            #   :description => self.email
            # )
            CreateTenant.create_tenant self
            Apartment::Tenant.switch()
            transactions = Stripe::BalanceTransaction.all(:limit => 1)
            unless transactions.first.nil?
              self.stripe_transaction_identifier = transactions.first.id
              CreateTenant.delay(:run_at => 1.seconds.from_now).create_tenant self
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
          end
        end
        self.status = 'completed'
        self.is_active = true
        self.save
      rescue Stripe::CardError => e
        self.status = 'failed'
        self.transaction_errors = e.message
        self.save
      end
  	end
  rescue Stripe::InvalidRequestError => e
    self.status = 'failed'
    self.transaction_errors = e.message
    self.save
  	logger.error "Stripe error while creating customer: #{e.message}"
  	errors.add :base, "There was a problem with your credit card."
  	false
  end
end
