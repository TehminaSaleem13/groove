  class SubscriptionsController < ApplicationController

    def new
      @subscription = Subscription.new
    end
    
    def select_plan
    	
    end

    def confirm_payment

      if @subscription = Subscription.create(stripe_user_token: params[:stripe_user_token], 
          tenant_name: params[:tenant_name], 
          amount: params[:amount], 
          subscription_plan_id: params[:plan_id], 
          email: params[:email], status: "started")

        if @subscription.save_with_payment
          render json: {valid: true, redirect_url: "subscriptions/show?transaction_id=#{@subscription.stripe_transaction_identifier}&notice=Thank you for your subscription!&amount=#{@subscription.amount}&email=#{@subscription.email}"}
        else
          render json: {valid: false}
        end
      else
        render json: {valid: false}
      end
    end

    def valid_tenant_name
      render json: {valid: Tenant.where(name: params[:tenant_name]).length == 0}
    end

    def valid_email
      render json: {valid: Subscription.where(email: params[:email]).length == 0}
    end

    def show
      flash[:notice] = params[:notice]   
    end

  end
