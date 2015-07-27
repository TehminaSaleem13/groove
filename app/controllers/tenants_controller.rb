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

    def search
      @result = Hash.new
      @result['status'] = true
      if !params[:search].nil? && params[:search] != ''
        @tenants = do_search(params, false)
        puts "@tenants: " + @tenants.inspect
        @result['tenants'] = make_tenants_list(@tenants['tenants'])
        @result['tenants_count'] = get_tenants_count
        @result['tenants_count']['search'] = @tenants['count']
      else
        @result['status'] = false
        @result['message'] = 'Improper search string'
      end
      puts "@result: " + @result.inspect
      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def gettenants
      @result = Hash.new
      @result[:status] = true
      @tenants = do_gettenants(params)
      @result['tenants'] = make_tenants_list(@tenants)
      @result['tenants_count'] = get_tenants_count()

      respond_to do |format|
            format.json { render json: @result}
      end
    end

    def do_gettenants(params)
      sort_key = 'updated_at'
      sort_order = 'DESC'
      limit = 10
      offset = 0
      query_add = ""
      supported_order_keys = ['ASC', 'DESC' ] #Caps letters only
      supported_sort_keys = ['updated_at', 'name']

      # Get passed in parameter variables if they are valid.
      limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

      offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0

      sort_order = params[:order] if !params[:order].nil? &&
          supported_order_keys.include?(params[:order].to_s)

      sort_key = params[:sort] if !params[:sort].nil? &&
        supported_sort_keys.include?(params[:sort].to_s)

      unless params[:select_all] || params[:inverted]
        query_add += " LIMIT "+limit.to_s+" OFFSET "+offset.to_s
      end

      tenants = Tenant.order(sort_key+" "+sort_order)
      unless params[:select_all] || params[:inverted]
        tenants =  tenants.limit(limit).offset(offset)
      end  

      if tenants.length == 0
        tenants = Tenant.where(1)
        unless params[:select_all] || params[:inverted]
          tenants =  tenants.limit(limit).offset(offset)
        end
      end
      return tenants
    end

    def do_search(params, results_only = true)
      limit = 10
      offset = 0
      sort_key = 'updated_at'
      sort_order = 'DESC'
      supported_sort_keys = ['updated_at', 'name']
      supported_order_keys = ['ASC', 'DESC' ] #Caps letters only

      sort_key = params[:sort] if !params[:sort].nil? &&
          supported_sort_keys.include?(params[:sort].to_s)

      sort_order = params[:order] if !params[:order].nil? &&
          supported_order_keys.include?(params[:order].to_s)

      # Get passed in parameter variables if they are valid.
      limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

      offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0
      search = ActiveRecord::Base::sanitize('%'+params[:search]+'%')
      query_add = ''

      unless params[:select_all] || params[:inverted]
        query_add = ' LIMIT '+limit.to_s+' OFFSET '+offset.to_s
      end
      Apartment::Tenant.switch()
      base_query = 'SELECT tenants.id as id, tenants.name as name, tenants.updated_at as updated_at
        FROM tenants
          WHERE
            (
              tenants.name like '+search+'
            )
            '+'
          GROUP BY tenants.id ORDER BY '+sort_key+' '+sort_order

      result_rows = Tenant.find_by_sql(base_query+query_add)

      puts "result_rows: " + result_rows.inspect
      if results_only
        result = result_rows
      else
        result = Hash.new
        result['tenants'] = result_rows
        if params[:select_all] || params[:inverted]
          result['count'] = result_rows.length
        else
          result['count'] = Tenant.count_by_sql('SELECT count(*) as count from('+base_query+') as tmp')
        end
      end
      puts "result: " + result.inspect

      return result
    end

    def make_tenants_list(tenants)
      @tenants_result = []
      tenants.each do |tenant|
        @tenant_hash = Hash.new
        @tenant_hash['id'] = tenant.id
        @tenant_hash['name'] = tenant.name

        @tenants_result.push(@tenant_hash)
      end
      return @tenants_result
    end

    def get_tenants_count
      count = Hash.new
      counts = Tenant.select('count(*) as count')
      all = 0
      counts.each do |single|
        # count[single.status] = single.count
        all += single.count
      end
      count['all'] = all
      count['search'] = 0
      count
    end
  end
