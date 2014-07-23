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


  def show
    @subscription = Subscription.find(params[:id])
    flash[:notice] = params[:notice]
    
  end
  # def check_tenant_name
  # 	if Apartment::Tenant.current_tenant == 'test'
  # 		render 'select_plan'
	# 	else
	#
	# 	end
  # end
end
