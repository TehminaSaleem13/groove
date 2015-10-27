module Groovepacker
  module Tenants
    class Helper
      include PaymentsHelper

      def do_gettenants(params)
        limit = 10
        offset = 0
        query_add = ""
        supported_order_keys = ['ASC', 'DESC'] #Caps letters only
        supported_sort_keys = ['updated_at', 'name']

        # Get passed in parameter variables if they are valid.
        limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

        offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0

        unless params[:select_all] || params[:inverted]
          query_add += " LIMIT "+limit.to_s+" OFFSET "+offset.to_s
        end

        tenants = Tenant.order('')
        unless params[:select_all] || params[:inverted]
          tenants = tenants.limit(limit).offset(offset)
        end

        if tenants.length == 0
          tenants = Tenant.where(1)
          unless params[:select_all] || params[:inverted]
            tenants = tenants.limit(limit).offset(offset)
          end
        end
        return tenants
      end

      def make_tenants_list(tenants, params)
        tenants_result = []
        begin
          tenants.each do |tenant|
            tenant_hash = {}
            tenant_hash['id'] = tenant.id
            tenant_hash['name'] = tenant.name
            plan_data = get_subscription_data(tenant.name)
            tenant_hash['start_day'] = plan_data['start_day']
            tenant_hash['plan'] = plan_data['plan']
            tenant_hash['progress'] = plan_data['progress']
            tenant_hash['transaction_errors'] = plan_data['transaction_errors']
            tenant_hash['stripe_url'] = plan_data['customer_id']
            tenant_hash['url'] = tenant.name + ".groovepacker.com"
            get_shipping_data = Groovepacker::Dashboard::Stats::ShipmentStats.new
            shipping_data = get_shipping_data.get_shipment_stats(tenant.name, true)
            tenant_hash['total_shipped'] = shipping_data['shipped_current']
            tenant_hash['shipped_last'] = shipping_data['shipped_last']
            tenant_hash['max_allowed'] = shipping_data['max_allowed']
            tenant_hash['average_shipped'] = shipping_data['average_shipped']
            tenant_hash['average_shipped_last'] = shipping_data['average_shipped_last']
            tenant_hash['shipped_last6'] = shipping_data['shipped_last6']

            tenants_result.push(tenant_hash)
          end
          unless params[:sort].nil? || params[:sort] == ''
            if params[:order] == 'DESC'
              tenants_result = tenants_result.sort_by { |v| v[params[:sort]].class == Fixnum ? v[params[:sort]] : v[params[:sort]].downcase }.reverse!
            else
              tenants_result = tenants_result.sort_by { |v| v[params[:sort]].class == Fixnum ? v[params[:sort]] : v[params[:sort]].downcase }
            end
          end
        rescue Exception => e
          puts e.message
        end
        return tenants_result
      end

      def do_search(params)
        limit = 10
        offset = 0
        sort_key = 'updated_at'
        sort_order = 'DESC'
        supported_sort_keys = ['updated_at', 'name']
        supported_order_keys = ['ASC', 'DESC'] #Caps letters only

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
          query_add = ' LIMIT '+limit.to_s+' OFFSET 0'
        end
        current_tenant = Apartment::Tenant.current_tenant
        Apartment::Tenant.switch()
        base_query = 'SELECT tenants.id as id, tenants.name as name, tenants.updated_at as updated_at, tenants.created_at as created_at, subscriptions.subscription_plan_id as plan, subscriptions.stripe_customer_id as stripe_url
          FROM tenants LEFT JOIN subscriptions ON (subscriptions.tenant_id = tenants.id) 
            WHERE
              (
                tenants.name like '+search+' OR subscriptions.subscription_plan_id like '+search+'
              )
              '+'
            GROUP BY tenants.id ORDER BY '+sort_key+' '+sort_order

        result_rows = Tenant.find_by_sql(base_query+query_add)
        result = Hash.new
        result['tenants'] = result_rows
        if params[:select_all] || params[:inverted]
          result['count'] = result_rows.length
        else
          result['count'] = Tenant.count_by_sql('SELECT count(*) as count from('+base_query+') as tmp')
        end
        Apartment::Tenant.switch(current_tenant)
        return result
      end

      def get_subscription_data(name)
        subscription_result = {}
        tenant = Tenant.where(name: name).first unless Tenant.where(name: name).empty?
        unless tenant.nil?
          subscription_result['plan'] = ""
          subscription_result['customer_id'] = ''
          subscription_result['progress'] = ''
          subscription_result['transaction_errors'] = ''
          unless tenant.subscription.nil?
            subscription = tenant.subscription
            case subscription.subscription_plan_id
              when "groove-solo"
                subscription_result['plan'] = "solo"
              when "groove-duo"
                subscription_result['plan'] = "duo"
              when "groove-trio"
                subscription_result['plan'] = "trio"
              when "groove-quinet"
                subscription_result['plan'] = "quinet"
              when "groove-symphony"
                subscription_result['plan'] = "symphony"
              when "annual-groove-solo"
                subscription_result['plan'] = "annual-solo"
              when "annual-groove-duo"
                subscription_result['plan'] = "annual-duo"
              when "annual-groove-trio"
                subscription_result['plan'] = "annual-trio"
              when "annual-groove-quinet"
                subscription_result['plan'] = "annual-quinet"
              when "annual-groove-symphony"
                subscription_result['plan'] = "annual-symphony"
              else
                subscription_result['plan'] = ""
            end
            subscription_result['start_day'] = subscription.created_at.strftime("%d %b") unless subscription.created_at.nil?
            subscription_result['customer_id'] = subscription.stripe_customer_id unless subscription.stripe_customer_id.nil?
            subscription_result['progress'] = subscription.progress unless subscription.progress.nil?
            subscription_result['transaction_errors'] =subscription.transaction_errors unless subscription.transaction_errors.nil?
          end
        end
        subscription_result
      end

      def delete_data(tenant, params, result, current_user)
        begin
          Apartment::Tenant.switch(tenant.name)
          if params[:action_type] == 'orders'
            delete_orders(result, current_user)
          elsif params[:action_type] == 'products'
            delete_products(result, current_user)
          elsif params[:action_type] == 'both'
            delete_orders(result, current_user)
            delete_products(result, current_user)
          elsif params[:action_type] == 'all'
            ActiveRecord::Base.connection.tables.each do |table|
              ActiveRecord::Base.connection.execute("TRUNCATE #{table}")
            end
            Groovepacker::SeedTenant.new.seed()
            users = User.where(:name => 'admin')
            unless users.empty?
              users.first.destroy unless users.first.nil?
            end
            subscription = tenant.subscription if tenant.subscription
            CreateTenant.apply_restrictions(subscription.subscription_plan_id) unless subscription.nil?
          end
        rescue Exception => e
          result['status'] = false
          result['error_messages'].push(e.message);
        end
      end

      def delete_orders(result, current_user)
        if current_user.can? 'add_edit_order_items'
          orders = Order.all
          unless orders.nil?
            orders.each do |order|
              if order.destroy
                result['status'] &= true
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

      def delete_products(result, current_user)
        if current_user.can?('delete_products')
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
        else
          result['status'] = false
          result['error_messages'].push('You do not have enough permissions to delete products')
        end
      end

      def delete(tenant, result)
        begin
          @tenant = Tenant.find_by_name(tenant)
          customer_id = @tenant.subscription.stripe_customer_id unless @tenant.subscription.nil? || @tenant.subscription.stripe_customer_id.nil?
          if @tenant.duplicate_tenant_id.nil?
            unless customer_id.nil?
              delete_customer(customer_id)
            end
          else
            subscription_data = @tenant.subscription
            duplicate_tenant_name = Tenant.find(@tenant.duplicate_tenant_id).name unless Tenant.find(@tenant.duplicate_tenant_id).nil?
            Subscription.create(email: subscription_data.email,
                                tenant_name: duplicate_tenant_name,
                                amount: subscription_data.amount,
                                stripe_user_token: subscription_data.stripe_user_token,
                                status: subscription_data.status, 
                                tenant_id: @tenant.duplicate_tenant_id,
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
            subscription_data.is_active = false
            subscription_data.save
          end
          Apartment::Tenant.drop(tenant)
          if @tenant.destroy
            result['status'] &= true
            result['success_messages'].push('Removed '+tenant+' from tenants table')
          end
        rescue Exception => e
          result['status'] &= false
          result['error_messages'].push(e.message)
        else
          result['success_messages'].push('Removed tenant '+tenant+' Database')
        end
      end

      def update_restrictions(tenant, params, result)
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
          result['status'] = false
          result['error_messages'].push(e.message);
        end
      end

      def duplicate(tenant, result, duplicate_name)
        begin
          current_tenant = tenant.name
          # Apartment::Tenant.create(duplicate_name)
          ActiveRecord::Base.connection.execute("CREATE DATABASE #{duplicate_name} CHARACTER SET latin1 COLLATE latin1_general_ci")
          ActiveRecord::Base.connection.tables.each do |tbale_name|
            ActiveRecord::Base.connection.execute("CREATE TABLE #{duplicate_name}.#{tbale_name} LIKE #{current_tenant}.#{tbale_name}")
            ActiveRecord::Base.connection.execute("INSERT INTO #{duplicate_name}.#{tbale_name} SELECT * FROM #{current_tenant}.#{tbale_name}")
          end
          Tenant.create(name: duplicate_name)
          @tenant = Tenant.find(tenant.id)
          @tenant.duplicate_tenant_id = Tenant.all.last.id
          @tenant.save
        rescue Exception => e
          result['status'] = false
          result['error_messages'].push(e.message);
        end
      end
    end
  end
end
