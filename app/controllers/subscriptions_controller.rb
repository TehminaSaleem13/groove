class SubscriptionsController < ApplicationController
	#before_filter: check_tenant_name
  def new
    @subscription = Subscription.new
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
    @subscription = Subscription.new(params[:subscription])
    @subscription.stripe_customer_token = params[:stripe_customer_token]
    if @subscription.save
      if @subscription.save_with_payment
        render json: {valid: true}
      else
        render json: {valid: false}
      end
    else
      puts @subscription.errors.full_messages.inspect
      render json: {valid: false}
    end
  end

  def valid_tenant_name
    tenant_name = params[:tenant_name]

    if Tenant.where(name: tenant_name).length > 0
      render json: {valid: false}
    else
      render json: {valid: true}
    end
  end

  def valid_email
    email = params[:email]

    if Subscription.where(email: email).length > 0
      render json: {valid: false}
    else
      render json: {valid: true}
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
