  class SubscriptionsController < ApplicationController
    include PaymentsHelper 
    before_filter :check_tenant_name

    def new
      @subscription = Subscription.new
      @monthly_amount = Stripe::Plan.retrieve(params[:plan_id]).amount
      @annually_amount = Stripe::Plan.retrieve('annual-' + params[:plan_id]).amount
    end

    def select_plan

    end

    def confirm_payment
      @subscription = Subscription.create(stripe_user_token: params[:stripe_user_token],
          tenant_name: params[:tenant_name],
          amount: params[:amount],
          subscription_plan_id: params[:plan_id],
          email: params[:email],
          user_name: params[:user_name],
          password: params[:password],
          status: "started")
      if @subscription
        if @subscription.save_with_payment
          render json: {valid: true, redirect_url: "subscriptions/show?transaction_id=#{@subscription.stripe_transaction_identifier}&notice=Congratulations! Your GroovePacker is being deployed!&amount=#{@subscription.amount}&email=#{@subscription.email}"}
        else
          render json: {valid: false}
        end
      else
        render json: {valid: false}
      end
    end

    def valid_tenant_name
      result = {}
      result['valid'] = true
      result['message'] = ''
      if Tenant.where(name: params[:tenant_name]).length == 0
        if (params[:tenant_name] =~ /^[a-zA-Z0-9][a-zA-Z0-9_]*[a-zA-Z0-9]$/).nil?
          result['valid'] = false
          result['message'] = 'Site name can only have alphabets, numbers and underscores. They cannot start or end with an underscore'
        end
      else
        result['valid'] = false
        result['message'] = 'https://' + params[:tenant_name] +'.groovepacker.com already exists'
      end
      render json: result
    end

    def valid_email
      render json: {valid: Subscription.where(email: params[:email]).length == 0}
    end

    def valid_username
      render json: {valid: Subscription.where(user_name: params[:user_name]).length == 0}
    end

    def show
      flash[:notice] = params[:notice]
    end

    def planInfo
      getPlanInfo(params[:plan_id])
      render json: @result
    end

    def check_tenant_name
      Apartment::Tenant.current_tenant==""?true:(render status: 401)
    end
  end
