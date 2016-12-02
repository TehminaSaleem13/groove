module Groovepacker
  module Tenants
    class Helper
      include ApplicationHelper
      include PaymentsHelper

      def do_gettenants(params)
        offset = params[:offset].to_i || 0
        limit = params[:limit].to_i || 10
        page_sort = params["pages_sort"]
        if page_sort == "true"
          tenants = Tenant.order('')
        else
          unless params[:select_all] || params[:inverted]
            tenants = Tenant.order('').limit(limit).offset(offset)
          end
        end
        tenants
      end

      def make_tenants_list(tenants, params)
        offset = params[:offset].to_i || 0
        limit = params[:limit].to_i || 10
        tenants_result = []
        tenants.each do |tenant|
          tenant_hash = {}
          tenant_name = tenant.name
          retrieve_tenant_data(tenant, tenant_hash)
          retrieve_plan_data(tenant_name, tenant_hash)
          retrieve_shipping_data(tenant_name, tenant_hash)
          retrieve_activity_data(tenant_name, tenant_hash)
          tenants_result.push(tenant_hash)
        end
        @sort = sort_param(params)
        if @sort && @sort != ''
          tenants_result = tenants_result.sort_by { |v| v[@sort].class == Fixnum ? v[@sort] : v[@sort].to_s.downcase }
          tenants_result.reverse! if params[:order] == 'DESC'
        end
        params["pages_sort"] == "true" ? tenants_result[offset, limit] : tenants_result
      end

      def do_search(params)
        query_add = ''
        sort_key = %w(updated_at name).include?(params[:sort]) ? params[:sort].to_s : 'updated_at'
        sort_order = %w(ASC DESC).include?(params[:order]) ? params[:order].to_s : 'DESC'

        # Get passed in parameter variables if they are valid.
        limit = params[:limit].to_i || 10

        search = ActiveRecord::Base::sanitize('%' + params[:search] + '%')

        unless params[:select_all] || params[:inverted]
          query_add = ' LIMIT ' + limit.to_s + ' OFFSET 0'
        end
        construct_query_and_get_result(params, search, sort_key, sort_order, query_add)
      end

      def get_subscription_data(name, state)
        subscription_result = subscription_result_hash
        @tenant = Tenant.where(name: name).first
        rec_subscription(@tenant, subscription_result)
        begin
          if state == "show"
            subscriptions = Stripe::Customer.retrieve(@tenant.subscription.stripe_customer_id).subscriptions  
            subscription_ids = subscriptions.data.map(&:id) 
            subscription_result['verified_stripe_account'] = subscription_ids.include? @tenant.subscription.customer_subscription_id
          end
        rescue
          subscription_result['verified_stripe_account'] = false
        end
        subscription_result["interval"] = @tenant.subscription.interval rescue nil
        subscription_result
      end

      def delete_data(tenant, params, result, current_user)
        begin
          Apartment::Tenant.switch(tenant.name)
          if params[:action_type] == 'orders'
            delete_orders(result)
          elsif params[:action_type] == 'products'
            delete_products(current_user)
          elsif params[:action_type] == 'both'
            delete_orders(result)
            delete_products(current_user)
          elsif params[:action_type] == 'all'
            ActiveRecord::Base.connection.tables.each do |table|
              ActiveRecord::Base.connection.execute("TRUNCATE #{table}") unless table == 'access_restrictions' || table == 'schema_migrations'
            end
            Groovepacker::SeedTenant.new.seed()
            users = User.where(:name => 'admin')
            unless users.empty?
              users.first.destroy unless users.first.nil?
            end
            subscription = tenant.subscription if tenant.subscription
            CreateTenant.new.apply_restrictions_and_seed(subscription)
          end
        rescue Exception => e
          result['status'] = false
          result['error_messages'].push(e.message);
        end
      end

      def take_action(action_type, result, current_user, tenant_name)
        case action_type
        when 'orders'
          delete_orders(result)
        when 'products'
          delete_products(current_user)
        when 'both'
          delete_orders(result)
          delete_products(current_user)
        when 'all'
          delete_all(tenant_name)
        end
      end

      def delete_orders(result)
        orders = Order.all
        return if orders.empty?
        orders.each do |order|
          if order.destroy
            result['status'] &= true
          else
            update_fail_status(result, order.errors.full_messages)
          end
        end
      end

      def delete_products(current_user)
        parameters = {}
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
      end

      def delete_all(tenant_name)
        ActiveRecord::Base.connection.tables.each do |table|
          ActiveRecord::Base.connection.execute("TRUNCATE #{table}") unless table == 'access_restrictions' || table == 'schema_migrations'
        end
        Groovepacker::SeedTenant.new.seed
        @user = User.where(name: 'admin').first
        @user.destroy if @user
        ApplyAccessRestrictions.new.apply_access_restrictions(tenant_name)
      end

      def delete(tenant)
        result = result_hash
        begin
          @tenant = Tenant.find_by_name(tenant)
          @subscription_data = @tenant.subscription
          update_parent(@tenant)
          if @subscription_data
            @customer_id = @subscription_data.stripe_customer_id
            destroy_tenant(@customer_id, @tenant, @subscription_data, result)
          else
            Apartment::Tenant.drop(tenant) if Apartment::tenant_names.include? (tenant)
            @tenant.destroy
          end
        rescue => e
          update_fail_status(result, e.message)
        else
          result['success_messages'].push('Removed tenant ' + tenant + ' Database')
        end
        result
      end

      def destroy_tenant(customer_id, tenant, subscription_data, result)
        if subscription_data && customer_id
          duplicate_tenant_id = tenant.duplicate_tenant_id
          tenant_name = tenant.name
          unless duplicate_tenant_id
            delete_customer(customer_id)
          else
            duplicate_tenant_name = Tenant.find(duplicate_tenant_id).name
            create_subscription(subscription_data, duplicate_tenant_name, tenant)
            subscription_data.is_active = false
            subscription_data.save
          end
          Apartment::Tenant.drop(tenant_name)
          if tenant.destroy
            result['success_messages'].push('Removed ' + tenant_name + ' from tenants table')
          end
        else
          update_fail_status(result, 'The tenant does not have a valid subscription')
        end
      end

      def create_subscription(subscription_data, duplicate_tenant_name, tenant)
        Subscription.create(
          email: subscription_data.email,
          tenant_name: duplicate_tenant_name,
          amount: subscription_data.amount,
          stripe_user_token: subscription_data.stripe_user_token,
          status: subscription_data.status,
          tenant_id: tenant.duplicate_tenant_id,
          stripe_transaction_identifier: subscription_data.stripe_transaction_identifier,
          created_at: subscription_data.created_at,
          updated_at: subscription_data.updated_at,
          transaction_errors: subscription_data.transaction_errors,
          subscription_plan_id: subscription_data.subscription_plan_id,
          customer_subscription_id: subscription_data.customer_subscription_id,
          stripe_customer_id: subscription_data.stripe_customer_id,
          is_active: true, password: subscription_data.password,
          user_name: subscription_data.user_name,
          coupon_id: subscription_data.coupon_id,
          progress: subscription_data.progress
        )
      end

      def update_restrictions(tenant, params)
        result = result_hash
        begin
          Apartment::Tenant.switch(tenant.name)
          @access_restriction = AccessRestriction.all.last
          return result unless @access_restriction
          access_restrictions_info = params["access_restrictions_info"]
          retrieve_and_save_restrictions(@access_restriction, access_restrictions_info)
        rescue => e
          update_fail_status(result, e.message)
        end
        result
      end

      def retrieve_and_save_restrictions(access_restriction, access_restrictions_info)
        access_restriction.num_shipments = access_restrictions_info["max_allowed"]
        access_restriction.num_users = access_restrictions_info["max_users"]
        access_restriction.num_import_sources = access_restrictions_info["max_import_sources"]
        access_restriction.allow_bc_inv_push = access_restrictions_info["allow_bc_inv_push"]
        access_restriction.allow_mg_rest_inv_push = access_restrictions_info["allow_mg_rest_inv_push"]
        access_restriction.allow_shopify_inv_push = access_restrictions_info["allow_shopify_inv_push"]
        access_restriction.allow_teapplix_inv_push = access_restrictions_info["allow_teapplix_inv_push"]
        access_restriction.allow_magento_soap_tracking_no_push = access_restrictions_info["allow_magento_soap_tracking_no_push"]
        access_restriction.save
      end

      def update_tenant(tenant, params)
        result = result_hash
        begin
          basic_tenant_info = params[:basicinfo]
          tenant.note = basic_tenant_info[:note] if basic_tenant_info[:note]
          tenant.addon_notes = basic_tenant_info[:addon_notes] if basic_tenant_info[:addon_notes]
          tenant.save
        rescue => e
          update_fail_status(result, e.message)
        end
        result
      end

      def update_subscription_plan(tenant, params)
        result = result_hash
        @subscription = tenant.subscription
        if @subscription
          @subscription_info = params[:subscription_info]
          @subscription.update_attributes(:customer_subscription_id => params[:subscription_info][:customer_subscription_id],:stripe_customer_id => params[:subscription_info][:customer_id], :subscription_plan_id => params[:subscription_info][:plan_id])
          return result unless (@subscription.amount.to_i != (@subscription_info[:amount].to_i * 100)) || (@subscription.interval != @subscription_info[:interval])
          begin
            create_new_plan_and_assign(tenant)
            update_modification_status(tenant)
          rescue Exception => ex
            result = check_exception(ex, result)
            Rollbar.error(ex, ex.message)
          end
        else
          update_fail_status(result, 'Couldn\'t find a valid subscription for the tenant.');
        end
        result
      end

      def check_exception(ex, result)
        result['status'] = false
        if ex.message.include?("does not have a subscription")
          result['error_messages'] = "Customer does not have any plan subscription."
        else
          result['error_messages'] = "Some error occured."
        end
        return result
      end

      def duplicate(id, duplicate_name)
        result = result_hash
        begin
          @tenant = Tenant.find(id)
          current_tenant = @tenant.name
          # Apartment::Tenant.create(duplicate_name)
          ActiveRecord::Base.connection.execute("CREATE DATABASE #{duplicate_name} CHARACTER SET latin1 COLLATE latin1_general_ci")
          ActiveRecord::Base.connection.tables.each do |table_name|
            ActiveRecord::Base.connection.execute("CREATE TABLE #{duplicate_name}.#{table_name} LIKE #{current_tenant}.#{table_name}")
            ActiveRecord::Base.connection.execute("INSERT INTO #{duplicate_name}.#{table_name} SELECT * FROM #{current_tenant}.#{table_name}")
          end
          created_tenant = Tenant.create(
            name: duplicate_name,
            initial_plan_id: @tenant.initial_plan_id,
            is_modified: @tenant.is_modified
          )
          created_tenant.update_attribute(:initial_plan_id, @tenant.initial_plan_id)
          @tenant.duplicate_tenant_id = created_tenant.id
          @tenant.save
          SendStatStream.new.delay.duplicate_groovlytic_tenant(current_tenant, duplicate_name)
        rescue => e
          update_fail_status(result, e.message)
        end
        result
      end

      def update_node(tenant, params)
        result = result_hash
        begin
          @subscription = tenant.subscription
          if @subscription && @subscription.stripe_customer_id
            if params['var'] == 'plan'
              plan_id = get_plan_id(params['value'])
              init = Groovepacker::Tenants::TenantInitialization.new
              init_access = init.access_limits(plan_id)
              update_restrictions(tenant, init_access)
              update_subcription_plan(@subscription, plan_id)
              @subscription.subscription_plan_id = plan_id
              @subscription.save!
            end
          end
        rescue => e
          update_fail_status(result, e.message)
        end
        result
      end

      def new_plan_info(tenant)
        rand_value = Random.new.rand(999).to_s
        time_now = Time.now.strftime('%y-%m-%d')
        return {
          'plan_id' => time_now + '-' + tenant.name + '-' + rand_value,
          'plan_name' => time_now + ' ' + tenant.name + ' ' + rand_value
        }
      end

      def update_modification_status(tenant)
        return if tenant.is_modified
        tenant.is_modified = true
        tenant.save
      end

      def retrieve_tenant_data(tenant, tenant_hash)
        tenant_hash['id'] = tenant.id
        tenant_hash['name'] = tenant.name
        tenant_hash['note'] = tenant.note
        tenant_hash['url'] = tenant.name + '.groovepacker.com'
        tenant_hash['is_modified'] = tenant.is_modified
      end

      def retrieve_plan_data(tenant_name, tenant_hash)
        plan_data = get_subscription_data(tenant_name, "index")
        tenant_hash['start_day'] = plan_data['start_day']
        tenant_hash['plan'] = plan_data['plan']
        tenant_hash['amount'] = plan_data['amount']
        tenant_hash['progress'] = plan_data['progress']
        tenant_hash['transaction_errors'] = plan_data['transaction_errors']
        tenant_hash['stripe_url'] = plan_data['customer_id']
        tenant_hash['url'] = tenant_name + ".groovepacker.com"
      end

      def retrieve_shipping_data(tenant_name, tenant_hash)
        get_shipping_data = Groovepacker::Dashboard::Stats::ShipmentStats.new
        shipping_data = get_shipping_data.get_shipment_stats(tenant_name, true)
        tenant_hash['total_shipped'] = shipping_data['shipped_current']
        tenant_hash['shipped_last'] = shipping_data['shipped_last']
        tenant_hash['max_allowed'] = shipping_data['max_allowed']
        tenant_hash['average_shipped'] = shipping_data['average_shipped']
        tenant_hash['average_shipped_last'] = shipping_data['average_shipped_last']
        tenant_hash['shipped_last6'] = shipping_data['shipped_last6']
      end

      def construct_query_and_get_result(params, search, sort_key, sort_order, query_add)
        result = result_hash
        current_tenant = Apartment::Tenant.current_tenant
        Apartment::Tenant.switch
        base_query = build_query(search, sort_key, sort_order)

        result['tenants'] = Tenant.find_by_sql(base_query + query_add)
        if params[:select_all] || params[:inverted]
          result['count'] = result['tenants'].length
        else
          result['count'] = Tenant.count_by_sql('SELECT count(*) as count from(' + base_query + ') as tmp')
        end
        Apartment::Tenant.switch(current_tenant)
        result
      end

      def build_query(search, sort_key, sort_order)
        'SELECT tenants.id as id, tenants.name as name, tenants.note as note, tenants.is_modified as is_modified, tenants.updated_at as updated_at, tenants.created_at as created_at, subscriptions.subscription_plan_id as plan, subscriptions.stripe_customer_id as stripe_url
          FROM tenants LEFT JOIN subscriptions ON (subscriptions.tenant_id = tenants.id)
            WHERE
              (
                tenants.name like ' + search + ' OR subscriptions.subscription_plan_id like ' + search + '
              )
              ' + '
            GROUP BY tenants.id ORDER BY ' + sort_key + ' ' + sort_order
      end

      def subscription_result_hash
        {
          'plan' => '',
          'plan_id' => '',
          'amount' => 0,
          'customer_id' => '',
          'progress' => '',
          'transaction_errors' => ''
        }
      end

      def retrieve_subscription_result(subscription_result, subscription)
        sub_plan_id = subscription.subscription_plan_id
        subscription_result['plan'] = construct_plan_hash.key(sub_plan_id) || sub_plan_id.capitalize.gsub("-"," ") #get_plan_name(sub_plan_id)
        subscription_result['plan_id'] = sub_plan_id
        subscription_result['amount'] = '%.2f' % [(subscription.amount * 100).round / 100.0 / 100.0] if subscription.amount
        subscription_result['start_day'] = subscription.created_at.strftime('%d %b')
        subscription_result['customer_id'] = subscription.stripe_customer_id if subscription.stripe_customer_id
        subscription_result['email'] = subscription.email if subscription.email
        subscription_result['progress'] = subscription.progress
        subscription_result['transaction_errors'] = subscription.transaction_errors if subscription.transaction_errors
        subscription_result['customer_subscription_id'] = subscription.customer_subscription_id
      end

      def create_new_plan_and_assign(tenant)
        plan_info = new_plan_info(tenant)
        plan_id = plan_info['plan_id']
        existing_plan = get_plan_info(@subscription_info[:plan_id])['plan_info']
        amount = @subscription_info[:amount].to_i * 100
        create_plan(amount,
                    @subscription_info[:interval] || @subscription.interval,
                    plan_info['plan_name'],
                    "usd",
                    plan_id)
        update_stripe_subscription(plan_id)
        update_app_subscription(plan_id, amount, @subscription_info[:interval])
        existing_plan.delete unless construct_plan_hash[@subscription_info[:plan]]
      end

      def update_stripe_subscription(plan_id)
        @customer = get_stripe_customer(@subscription.stripe_customer_id)
        if @customer
          subscription = @customer.subscriptions.retrieve(@subscription.customer_subscription_id)
          @trial_end_time = subscription.trial_end
          if @trial_end_time && (@trial_end_time > Time.now.to_i)
            @customer.update_subscription(plan: plan_id, trial_end: @trial_end_time, prorate: false)
          else
            @customer.update_subscription(plan: plan_id, prorate: true)
          end
        end
      end

      def update_app_subscription(plan_id, amount, interval)
        @subscription.subscription_plan_id = plan_id
        @subscription.amount = amount
        @subscription.interval = interval if interval
        @subscription.save
      end

      def retrieve_activity_data(tenant_name, tenant_hash)
        tenant_hash['last_activity'] = activity_data_hash
        current_tenant = Apartment::Tenant.current
        begin
          Apartment::Tenant.switch(tenant_name)
          tenant_hash['last_activity']['most_recent_login'] = most_recent_login
          tenant_hash['last_activity']['most_recent_scan'] = most_recent_scan
          tenant_hash['most_recent_activity'] = most_recent_login['date_time']
        rescue => e
          tenant_hash['most_recent_activity'] = nil
        end
        Apartment::Tenant.switch(current_tenant)
      end

      def activity_data_hash
        {
          'most_recent_login' => {
            'date_time' => nil,
            'user' => ''
          },
          'most_recent_scan' => {
            'date_time' => nil,
            'user' => ''
          }
        }
      end

      def most_recent_login
        most_recent_login_data = {}
        @user = User.where('username != ? and current_sign_in_at IS NOT NULL', 'gpadmin').order('current_sign_in_at desc').first
        if @user
          most_recent_login_data['date_time'] = @user.current_sign_in_at
          most_recent_login_data['user'] = @user.username
        end
        most_recent_login_data
      end

      def most_recent_scan
        most_recent_scan_data = {}
        @order = Order.where('status = ?', 'scanned').order('scanned_on desc').first
        if @order
          most_recent_scan_data['date_time'] = @order.scanned_on
          most_recent_scan_data['user'] = User.find_by_id(@order.packing_user_id).username rescue nil
        end
        most_recent_scan_data
      end

      def rec_subscription(tenant, subscription_result)
        if tenant
          @subscription = tenant.subscription
          if @subscription
            retrieve_subscription_result(subscription_result, @subscription)
          else
            parent_tenant = Tenant.find_by_duplicate_tenant_id(tenant.id)
            rec_subscription(parent_tenant, subscription_result)
          end
        end
      end

      def sort_param(params)
        return 'most_recent_activity' if params[:sort] == 'last_activity'
        params[:sort]
      end

      def update_parent(tenant)
        parent = Tenant.find_by_duplicate_tenant_id(tenant.id)
        parent.update_attribute(:duplicate_tenant_id, nil) if parent
      end
    end
  end
end
