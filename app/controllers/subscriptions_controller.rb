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
      session[:subscription] = @subscription
      render 'process_pay'
    end 
  end

  def process_pay
  
  end

  def show
    @subscription = session[:subscription]
    id = @subscription.id
    @subscription = Subscription.find(id)
    # token = params[:stripeToken]
    if @subscription.save_with_payment
      redirect_to subscriptions_path(@subscription), :notice => "Thankyou for subscribing!"
    else
      render 'select_plan'
    end  
  end
  # def check_tenant_name
  # 	if Apartment::Tenant.current_tenant == 'test'
  # 		render 'select_plan'
	# 	else
	#
	# 	end
  # end
end
