  class TenantsController < ApplicationController
    include PaymentsHelper
    # before_filter :check_tenant_name

    def free_subscription
      getAllPlans()
      if @result['status']==true
        @result = @result['all_plans']
      end
    end

    def get_plan_info
      getPlanWithIndex(params[:plan_index])
      if @result['status']==true
        @result = @result['plan']
      end
      render json: @result
    end

    def create_tenant
      @subscription = Subscription.create(tenant_name: params[:tenant_name],
          amount: params[:amount],
          subscription_plan_id: params[:plan_id],
          email: params[:email],
          user_name: params[:user_name],
          password: params[:password],
          status: "started") 
      if @subscription
        if @subscription.save_with_payment(0)
          @result = getNextPaymentDate(@subscription)
          render json: {valid: true, redirect_url: "show?transaction_id=#{@subscription.stripe_transaction_identifier}&notice=Congratulations! Your GroovePacker is being deployed!&email=#{@subscription.email}&next_date=#{@result['next_date']}"}
        else
          render json: {valid: false}
        end
      else
        render json: {valid: false}
      end
    end

    def getinfo
      @result = Hash.new
      @result['status'] = true
      @result['messages'] = []
      @tenants = Tenant.all
      if @tenants.empty?
        @result['status'] = false
      else
        @result['tenants'] = @tenants
      end
      respond_to do |format|
        format.json { render json: @result}
      end
    end
  end
