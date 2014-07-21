class SubscriptionsController < ApplicationController
	# before_filter: check_tenant_name
  def new
  	Apartment::Tenant.switch()
  	@subscription = Subscription.new
  end
  def select_plan
  	
  end
  def collect_information
  	
  end
  def create
  	Apartment::Tenant.switch()
  	@subscription = Subscription.new(params[:subscription])
  	if @subscription.save_with_payment
  		redirect_to subscriptions_path(@subscription), :notice => "Thankyou for subscribing!"
  	else
  		render 'new'
  	end
  end
  # def show
  #   @subscription = Subscription.find(params[:id])
  # end
  # def check_tenant_name
  # 	if Apartment::Tenant.current_tenant == 'test'
  # 		render 'select_plan'
	# 	else
	#
	# 	end
  # end
end
