class SubscriptionsController < ApplicationController
	#before_filter: check_tenant_name
  def new
    # @subscription = Subscription.new
   	@plan = params
  end
  
  def select_plan
  	
  end
  
  def create
    @subscription = Subscription.new
  	
  end

  def process_pay
    @subscription = Subscription.new(params[:subscription])
   #  token = params[:stripeToken]
    if @subscription.save_with_payment
      redirect_to subscriptions_path(@subscription), :notice => "Thankyou for subscribing!"
      # redirect_to subscriptions_show, :notice => "Thankyou for subscribing!"
    else
      render 'create'
    end  
  end

  def show
    @subscription = Subscription.find(params[:id])
  end
  # def check_tenant_name
  # 	if Apartment::Tenant.current_tenant == 'test'
  # 		render 'select_plan'
	# 	else
	#
	# 	end
  # end
end
