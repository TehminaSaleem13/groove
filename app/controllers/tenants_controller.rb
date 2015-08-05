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
        @result['tenants'] = make_tenants_list(@tenants['tenants'])
        @result['tenants_count'] = get_tenants_count
        @result['tenants_count']['search'] = @tenants['count']
      else
        @result['status'] = false
        @result['message'] = 'Improper search string'
      end

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

      return result
    end

    def make_tenants_list(tenants)
      @tenants_result = []
      tenants.each do |tenant|
        @tenant_hash = Hash.new
        @tenant_hash['id'] = tenant.id
        @tenant_hash['name'] = tenant.name
        plan_data = get_subscription_data(tenant.id)
        @tenant_hash['plan'] = plan_data['plan']
        @tenant_hash['stripe_url'] = plan_data['customer_id']
        shipping_data = get_shipping_data(tenant.id)
        @tenant_hash['total_shipped'] = shipping_data['shipped_current']
        @tenant_hash['shipped_last'] = shipping_data['shipped_last']
        @tenant_hash['max_allowed'] = shipping_data['max_allowed']
        @tenant_hash['url'] = tenant.name + ".groovepacker.com"

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

    def get_subscription_data(id)
      @subscripton_result = Hash.new
      current_tenant = Apartment::Tenant.current_tenant
      Apartment::Tenant.switch()
      tenant = Tenant.find(id)
      unless tenant.nil?
        unless tenant.subscription.nil?
          subscription = tenant.subscription
          case subscription.subscription_plan_id
          when "groove-solo"
            @subscripton_result['plan'] = "solo"
          when "groove-duo"
            @subscripton_result['plan'] = "duo"
          when "groove-trio"
            @subscripton_result['plan'] = "trio"
          when "groove-quinet"
            @subscripton_result['plan'] = "quinet"
          when "groove-symphony"
            @subscripton_result['plan'] = "symphony"    
          when "annual-groove-solo"
            @subscripton_result['plan'] = "annual-solo"
          when "annual-groove-duo"
            @subscripton_result['plan'] = "annual-duo"
          when "annual-groove-trio"
            @subscripton_result['plan'] = "annual-trio"
          when "annual-groove-quinet"
            @subscripton_result['plan'] = "annual-quinet"
          when "annual-groove-symphony"
            @subscripton_result['plan'] = "annual-symphony"
          end
          @subscripton_result['customer_id'] = subscription.stripe_customer_id
        end
      else
        @subscripton_result['plan'] = ""
      end
      Apartment::Tenant.switch(current_tenant)
      @subscripton_result
    end

    def get_shipping_data(id)
      @shipping_result = Hash.new
      @shipping_result['shipped_current'] = 0
      @shipping_result['shipped_last'] = 0
      @shipping_result['max_allowed'] = 0
      tenant = Tenant.find(id)
      unless tenant.nil?
        begin
          Apartment::Tenant.switch(tenant.name)
          unless AccessRestriction.all.first.nil?
            access_restrictions = AccessRestriction.all
            data_length = access_restrictions.length
            @shipping_result['shipped_current'] = access_restrictions[data_length - 1].total_scanned_shipments
            @shipping_result['shipped_last'] = access_restrictions[data_length - 2].total_scanned_shipments if data_length > 1
            @shipping_result['max_allowed'] = access_restrictions[data_length - 1].num_shipments
            @shipping_result['max_users'] = access_restrictions[data_length-1].num_users
            @shipping_result['max_import_sources'] = access_restrictions[data_length-1].num_import_sources
          else
            @shipping_result['shipped_current'] = 0
            @shipping_result['shipped_last'] = 0
            @shipping_result['max_allowed'] = 0
            @shipping_result['max_users'] = 0
            @shipping_result['max_import_sources'] = 0
          end
        rescue
          @shipping_result['shipped_current'] = 0
          @shipping_result['shipped_last'] = 0
          @shipping_result['max_allowed'] = 0
          @shipping_result['max_users'] = 0
          @shipping_result['max_import_sources'] = 0
        end
      end
      Apartment::Tenant.switch()
      @shipping_result
    end

    def getdetails
      @result = Hash.new
      @tenant = nil
      if !params[:id].nil?
        @tenant = Tenant.find_by_id(params[:id])
      end
      if !@tenant.nil?
        @tenant.reload
        general_setting = GeneralSetting.all.first
        scan_pack_setting = ScanPackSetting.all.first

        @result['tenant'] = Hash.new
        @result['tenant']['basicinfo'] = @tenant.attributes
        @result['tenant']['subscription_info'] = get_subscription_data(params[:id])
        @result['tenant']['access_restrictions_info'] = get_shipping_data(params[:id])
      end

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def update_access_restrictions
      @result = Hash.new
      @result['status'] = true
      @result['error_messages'] = []
      @tenant = nil
      tenant = Tenant.find(params[:basicinfo][:id])
      unless tenant.nil?
        begin
          Apartment::Tenant.switch(tenant.name)
          unless AccessRestriction.all.first.nil?
            access_restrictions = AccessRestriction.all
            data_length = access_restrictions.length
            access_restrictions[data_length - 1].num_shipments = params[:access_restrictions_info][:max_allowed]
            access_restrictions[data_length-1].num_users = params[:access_restrictions_info][:max_users]
            access_restrictions[data_length-1].num_import_sources = params[:access_restrictions_info][:max_import_sources]
            access_restrictions[data_length-1].save
          end
        rescue Exception => e
          @result['status'] = false
          @result['error_messages'].push(e.message);
        end
      else
        @result['status'] = false
      end
      Apartment::Tenant.switch('groovepackeradmin')

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def delete_tenant_data
      @result = Hash.new
      @result['status'] = true
      @result['error_messages'] = []
      @tenant = nil
      tenant = Tenant.find(params[:id])
      unless tenant.nil?
        begin
          Apartment::Tenant.switch(tenant.name)
          if params[:action_type] == 'orders'
            delete_orders(@result)
          elsif params[:action_type] == 'products'
            delete_products(@result)
          elsif params[:action_type] == 'both'
            delete_orders(@result)
            delete_products(@result)
          elsif params[:action_type] == 'all'
            ActiveRecord::Base.connection.tables.each do |table|
              ActiveRecord::Base.connection.execute("TRUNCATE #{table}")
            end   
          end
        rescue Exception => e
          @result['status'] = false
          @result['error_messages'].push(e.message);
        end
      else
        @result['status'] = false
      end
      Apartment::Tenant.switch()

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def delete_orders(result)
      if current_user.can? 'add_edit_order_items'
        orders = Order.all
        unless orders.nil?
          orders.each do|order|
            if order.destroy
              @result['status'] &= true
            else
              result['status'] &= false
              result['error_messages'] = order.errors.full_messages
            end
          end
        end
      else
        result['status'] = false
        result['error_messages'].push("You do not have enough permissions to delete order")
      end
    end

    def delete_products(result)
      if current_user.can?('delete_products')
        parameters = Hash.new
        parameters[:select_all] = true
        parameters[:inverted] = false
        parameters[:filter] = 'all'
        parameters[:is_kit] = '-1'
        bulk_actions = Groovepacker::Products::BulkActions.new
        groove_bulk_actions = GrooveBulkActions.new
        groove_bulk_actions.identifier = 'product'
        groove_bulk_actions.activity = 'delete'
        groove_bulk_actions.save

        bulk_actions.delete(Apartment::Tenant.current, parameters, groove_bulk_actions.id, current_user.username)
      else
        result['status'] = false
        result['error_messages'].push('You do not have enough permissions to delete products')
      end
    end
  end
