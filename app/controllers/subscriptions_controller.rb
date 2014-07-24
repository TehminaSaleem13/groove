class SubscriptionsController < ApplicationController
	#before_filter: check_tenant_name
  def new
    @subscription = Subscription.new(params[:subscription])
   	@plan = params
  end
  
  def select_plan
  	
  end
  
  def create
  	@subscription = Subscription.new(params[:subscription])
    @subscription.status = 'started'
    if @subscription.password == @subscription.password_confirmation
      if @subscription.save
        redirect_to :action => 'process_pay', :id => @subscription.id
      else
        redirect_to :action => 'new', :subscription => params[:subscription]
      end 
    else
      redirect_to :action => 'new', :subscription => params[:subscription]
    end
  end

  def process_pay
    @id = params[:id]
  end

  def confirm_payment
    puts "params" + params.inspect
    @subscription = Subscription.find(params[:id])
    @subscription.stripe_customer_token = params[:stripe_customer_token]
    puts "subscription saving"
    if @subscription.save
      puts "subscription saved"
      

      if @subscription.save_with_payment
        render json: true
      else
        render json: false
      end
    else
      puts @subscription.errors.full_messages.inspect
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
