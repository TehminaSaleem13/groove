class SubscriptionsController < ApplicationController
	#before_filter: check_tenant_name
  def new
    @subscription = Subscription.new
   	@plan = params
  end
  
  def select_plan
  	
  end
  
  def create
  	@subscription = Subscription.new(params[:subscription])
    @subscription.status = 'started'
    if @subscription.save
      redirect_to :action => 'process_pay', :id => @subscription.id
    end 
  end

  def process_pay
    @id = params[:id]
  end

  def confirm_payment
    puts "params" + params.inspect
    @subscription = Subscription.find(params[:id])
    @subscription.stripe_customer_token = params[:stripe_customer_token]
    @subscription.save
    

    if @subscription.save_with_payment
      render json: "ok"
    else
      render json: "failure"
    end
  end

  def save_with_payment(subscription)
    if !subscription.nil?
      begin
        Stripe::Charge.create(
          :amount => subscription.amount,
          :currency => "usd",
          :card => subscription.stripe_customer_token,
          :description => subscription.email
        )
      rescue Stripe::CardError => e
        subscription.status = 'failed'
        subscription.save
        puts "Card declined"
        puts e.inspect
      end
      subscription.status = 'completed'
      subscription.save 
      save!
    end
  rescue Stripe::InvalidRequestError => e
    subscription.status = 'failed'
    subscription.save
    logger.error "Stripe error while creating customer: #{e.message}"
    errors.add :base, "There was a problem with your credit card."
    false
  end

  def show
    # @subscription = Subscription.find(params[:id])

    # if @subscription.save_with_payment
    #   redirect_to subscriptions_path(@subscription), :notice => "Thankyou for subscribing!"
    # else
    #   render 'select_plan'
    # end  
  end
  # def check_tenant_name
  # 	if Apartment::Tenant.current_tenant == 'test'
  # 		render 'select_plan'
	# 	else
	#
	# 	end
  # end
end
