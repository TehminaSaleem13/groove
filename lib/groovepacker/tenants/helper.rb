# frozen_string_literal: true

module Groovepacker
  module Tenants
    class Helper
      include ApplicationHelper
      include PaymentsHelper

      def do_gettenants(params)
        offset = params[:offset].to_i || 0
        limit = params[:limit].to_i || 10
        page_sort = params['pages_sort']
        if page_sort == 'true'
          tenants = Tenant.order('')
        else
          tenants = Tenant.order('').limit(limit).offset(offset) unless params[:select_all] || params[:inverted]
        end
        tenants
      end

      def make_tenants_list(tenants, params)
        offset = params[:offset].to_i || 0
        limit = params[:limit].to_i || 10
        tenants_result = []

        @tenants = tenants
        @tenant_names = tenants.map(&:name)

        ActiveRecord::Associations::Preloader.new.preload(tenants, :subscription)
        latest_scanned_order_for_all_tenants
        latest_scanned_order_packing_user_for_all_tenants
        get_access_restrictions_for_all_tenants
        recent_login_all_tenants
        parent_tenant_for_all_tenants

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
          tenants_result = tenants_result.sort_by { |v| v[@sort].class == Integer ? v[@sort] : v[@sort].to_s.downcase }
          tenants_result = tenants_result.sort_by { |v|  v['latest_activity'].to_i } if @sort == 'most_recent_activity'
          tenants_result = tenants_result.sort_by { |v|  v['last_charge_in_stripe'].to_i } if @sort == 'last_charge_in_stripe'
          tenants_result.reverse! if params[:order] == 'DESC'
        end
        params['pages_sort'] == 'true' ? tenants_result[offset, limit] : tenants_result
      end

      def do_search(params)
        query_add = ''
        sort_key = %w[updated_at name].include?(params[:sort]) ? params[:sort].to_s : 'updated_at'
        sort_order = %w[ASC DESC].include?(params[:order]) ? params[:order].to_s : 'DESC'

        # Get passed in parameter variables if they are valid.
        limit = params[:limit].to_i || 10

        search = ActiveRecord::Base.connection.quote('%' + params[:search] + '%')

        query_add = ' LIMIT ' + limit.to_s + ' OFFSET 0' unless params[:select_all] || params[:inverted]
        construct_query_and_get_result(params, search, sort_key, sort_order, query_add)
      end

      def get_subscription_data(name, state)
        subscription_result = subscription_result_hash

        @tenant = @tenants ? @tenants.find { |t| t.name.eql?(name) } : Tenant.find_by_name(name)

        rec_subscription(@tenant, subscription_result)
        begin
          if state == 'show'
            subscriptions = Stripe::Subscription.list(customer: @tenant.subscription.stripe_customer_id)
            subscription_ids = subscriptions.data.map(&:id)
            subscription_result['verified_stripe_account'] = subscription_ids.include? @tenant.subscription.customer_subscription_id
          end
        rescue StandardError
          subscription_result['verified_stripe_account'] = false
        end
        subscription_result['interval'] = begin
                                            @tenant.subscription.interval
                                          rescue StandardError
                                            nil
                                          end
        subscription_result['shopify_customer'] = begin
                                                    @tenant.subscription.shopify_customer
                                                  rescue StandardError
                                                    nil
                                                  end
        subscription_result
      end

      def delete_data(tenant, params, result, current_user)
        Apartment::Tenant.switch!(tenant.name)
        if params[:action_type] == 'orders'
          delete_orders(result)
        elsif params[:action_type] == 'products'
          delete_products(current_user)
        elsif params[:action_type] == 'both'
          delete_all_orders
          delete_all_product_data
        elsif params[:action_type] == 'inventory'
          helper = Groovepacker::Tenants::Helper.new
          helper.delay(priority: 95).reset_inventory(result, Apartment::Tenant.current)
        elsif params[:action_type] == 'all'
          ActiveRecord::Base.connection.tables.each do |table|
            ActiveRecord::Base.connection.execute("TRUNCATE #{table}") unless table == 'access_restrictions' || table == 'schema_migrations' || table == 'users'
          end
          # Groovepacker::SeedTenant.new.seed()
          # users = User.where(:name => 'admin')
          # unless users.empty?
          #   users.first.destroy unless users.first.nil?
          # end
          User.where('username != ?', 'gpadmin').destroy_all
          subscription = tenant.subscription if tenant.subscription
          CreateTenant.new.apply_restrictions_and_seed(subscription)
        end
        result
      rescue Exception => e
        result['status'] = false
        result['error_messages'].push(e.message)
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

      def delete_all_orders
        %w[orders order_activities order_items order_serials packing_cams order_item_boxes order_item_kit_product_scan_times order_item_kit_products order_item_order_serial_product_lots order_item_scan_times order_shippings order_serials order_tags order_tags_orders order_exceptions shipping_labels shipstation_label_data].each do |table|
          ActiveRecord::Base.connection.execute("TRUNCATE #{table}")
        end
      end

      def delete_all_product_data
        %w[products product_activities product_cats product_images products_product_inventory_reports product_inventory_warehouses product_kit_activities product_kit_skus product_lots product_skus product_barcodes totes tote_sets].each do |table|
          ActiveRecord::Base.connection.execute("TRUNCATE #{table}")
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

      def reset_inventory(_result, tenant)
        Apartment::Tenant.switch! tenant
        ProductInventoryWarehouses.where('allocated_inv != 0').each(&:update_allocated_inv)
      end

      def delete_all(tenant_name)
        ActiveRecord::Base.connection.tables.each do |table|
          ActiveRecord::Base.connection.execute("TRUNCATE #{table}") unless table == 'access_restrictions' || table == 'schema_migrations' || table == 'users'
        end
        # Groovepacker::SeedTenant.new.seed
        # @user = User.where(name: 'admin').first
        # @user.destroy if @user
        User.where('username != ?', 'gpadmin').destroy_all
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
            @subscription_data.update(tenant_name: "#{tenant}-deleted", email: @subscription_data.email.to_s + '-deleted')
            destroy_tenant(@customer_id, @tenant, @subscription_data, result)
          else
            Apartment::Tenant.drop(tenant) if Apartment.tenant_names.include? tenant
            @tenant.destroy
          end
        rescue StandardError => e
          update_fail_status(result, e.message)
        else
          result['success_messages'].push('Removed tenant ' + tenant + ' Database')
        end
        result
      end

      def destroy_tenant(customer_id, tenant, subscription_data, result)
        # if subscription_data && customer_id
        duplicate_tenant_id = tenant.duplicate_tenant_id
        tenant_name = tenant.name
        if duplicate_tenant_id
          begin
            duplicate_tenant_name = Tenant.find(duplicate_tenant_id).name
            create_subscription(subscription_data, duplicate_tenant_name, tenant)
            subscription_data.is_active = false
            subscription_data.save
          rescue StandardError
          end
        else
          begin
            delete_customer(customer_id)
          rescue StandardError
            nil
          end
        end
        Apartment::Tenant.drop(tenant_name)
        result['success_messages'].push('Removed ' + tenant_name + ' from tenants table') if tenant.destroy
        # else
        #   update_fail_status(result, 'The tenant does not have a valid subscription')
        # end
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
          Apartment::Tenant.switch!(tenant.name)
          @access_restriction = AccessRestriction.all.last
          unless params['basicinfo']['is_multi_box']
            setting = GeneralSetting.all.first
            setting.update_attribute(:multi_box_shipments, false)
          end

          return result unless @access_restriction

          access_restrictions_info = params['access_restrictions_info']
          retrieve_and_save_restrictions(@access_restriction, access_restrictions_info)
        rescue StandardError => e
          update_fail_status(result, e.message)
        end
        result
      end

      def retrieve_and_save_restrictions(access_restriction, access_restrictions_info)
        access_restriction.num_shipments = access_restrictions_info['max_allowed']
        access_restriction.num_users = access_restrictions_info['max_users'] 
        access_restriction.regular_users = access_restrictions_info['regular_users'] 
        access_restriction.administrative_users = access_restrictions_info['max_administrative_users']
        access_restriction.num_import_sources = access_restrictions_info['max_import_sources']
        access_restriction.allow_bc_inv_push = access_restrictions_info['allow_bc_inv_push']
        access_restriction.allow_mg_rest_inv_push = access_restrictions_info['allow_mg_rest_inv_push']
        access_restriction.allow_shopify_inv_push = access_restrictions_info['allow_shopify_inv_push']
        access_restriction.allow_shopline_inv_push = access_restrictions_info['allow_shopline_inv_push']
        access_restriction.allow_teapplix_inv_push = access_restrictions_info['allow_teapplix_inv_push']
        access_restriction.allow_magento_soap_tracking_no_push = access_restrictions_info['allow_magento_soap_tracking_no_push']
        access_restriction.save
      end

      def update_tenant(tenant, params)
        result = result_hash
        begin
          basic_tenant_info = params[:basicinfo]
          tenant.note = basic_tenant_info[:note] if basic_tenant_info[:note]
          tenant.addon_notes = basic_tenant_info[:addon_notes] if basic_tenant_info[:addon_notes]
          tenant.activity_log = basic_tenant_info[:activity_log] if basic_tenant_info[:activity_log]
          tenant.save
        rescue StandardError => e
          update_fail_status(result, e.message)
        end
        result
      end

      def update_subscription_plan(tenant, params)
        result = result_hash
        @subscription = tenant.subscription
        if @subscription
          @subscription_info = params[:subscription_info]
          @subscription.update(customer_subscription_id: params[:subscription_info][:customer_subscription_id], stripe_customer_id: params[:subscription_info][:customer_id], subscription_plan_id: params[:subscription_info][:plan_id])
          return result unless (@subscription.amount.to_i != (@subscription_info[:amount].to_i * 100)) || (@subscription.interval != @subscription_info[:interval])

          begin
            create_new_plan_and_assign(tenant)
            update_modification_status(tenant)
          rescue Exception => e
            result = check_exception(e, result)
            Rollbar.error(e, e.message)
          end
        else
          update_fail_status(result, 'Couldn\'t find a valid subscription for the tenant.')
        end
        result
      end

      def check_exception(ex, result)
        result['status'] = false
        result['error_messages'] = if ex.message.include?('does not have a subscription')
                                     'Customer does not have any plan subscription.'
                                   else
                                     'Some error occured.'
                                   end
        result
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
          created_tenant.update( activity_log: @tenant.activity_log, custom_product_fields: @tenant.custom_product_fields, product_activity_switch: @tenant.product_activity_switch, is_multi_box: @tenant.is_multi_box, is_fba: @tenant.is_fba, allow_rts: @tenant.allow_rts, scheduled_import_toggle: @tenant.scheduled_import_toggle, product_ftp_import: @tenant.product_ftp_import, inventory_report_toggle: @tenant.inventory_report_toggle, api_call: @tenant.api_call, groovelytic_stat: @tenant.groovelytic_stat, is_delay: @tenant.is_delay, delayed_inventory_update: @tenant.delayed_inventory_update, daily_packed_toggle: @tenant.daily_packed_toggle, ss_api_create_label: @tenant.ss_api_create_label, direct_printing_options: @tenant.direct_printing_options, order_cup_direct_shipping: @tenant.order_cup_direct_shipping, store_order_respose_log: @tenant.store_order_respose_log,expo_logs_delay: @tenant.expo_logs_delay, packing_cam: @tenant.packing_cam, gdpr_shipstation: @tenant.gdpr_shipstation, uniq_shopify_import: @tenant.uniq_shopify_import, scan_pack_workflow: @tenant.scan_pack_workflow, test_tenant_toggle: @tenant.test_tenant_toggle )
          created_tenant.price = { 'bigCommerce_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'shopify_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'shopline_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'magento2_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'teapplix_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'product_activity_log_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'magento_soap_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'multi_box_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'amazon_fba_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'post_scanning_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'allow_Real_time_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'import_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'inventory_report_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'custom_product_fields_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'enable_developer_tools_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'high_sku_feature' => { 'toggle' => false, 'amount' => 50, 'stripe_id' => '' }, 'double_high_sku' => { 'toggle' => false, 'amount' => 100, 'stripe_id' => '' }, 'cust_maintenance_1' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'cust_maintenance_2' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'groovelytic_stat_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'product_ftp_import' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' } }
          created_tenant.save
          Subscription.create!(tenant_name: created_tenant.name, tenant_id: created_tenant.id, progress: 'transaction_complete', interval: 'month', status: 'completed', user_name: 'test', password: '12345678', subscription_plan_id: created_tenant.initial_plan_id)
          Apartment::Tenant.switch! created_tenant.name
          ExportSetting.last.update(auto_email_export: false , auto_stat_email_export: false )
          GeneralSetting.last.update(scheduled_order_import: false)
          ShopifyCredential.all.update(webhook_order_import: false)
          @tenant.duplicate_tenant_id = created_tenant.id
          @tenant.save
          SendStatStream.new.delay(priority: 95).duplicate_groovlytic_tenant(current_tenant, duplicate_name)
        rescue StandardError => e
          update_fail_status(result, e.message)
          Rollbar.error(e, e.message, Apartment::Tenant.current)
        end
        result
      end

      def update_node(tenant, params)
        result = result_hash
        begin
          @subscription = tenant.subscription
          if @subscription&.stripe_customer_id
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
        rescue StandardError => e
          update_fail_status(result, e.message)
        end
        result
      end

      def new_plan_info(tenant)
        rand_value = Random.new.rand(999).to_s
        time_now = Time.current.strftime('%y-%m-%d')
        {
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
        tenant_hash['url'] = tenant.name + '.' + ENV['FRONTEND_HOST']
        tenant_hash['is_modified'] = tenant.is_modified
        tenant_hash['scheduled_import_toggle'] = tenant.scheduled_import_toggle
        tenant_hash['inventory_report_toggle'] = tenant.reload.inventory_report_toggle
        tenant_hash['test_tenant_toggle'] = tenant.reload.test_tenant_toggle
        tenant_hash['is_cf'] = tenant.reload.is_cf
        tenant_hash['last_charge_in_stripe'] = begin
                                                 tenant.last_charge_in_stripe.strftime('%a %m/%e/%Y %l:%M:%S %p')
                                               rescue StandardError
                                                 nil
                                               end
        Apartment::Tenant.switch! tenant.name
        tenant_hash['last_import_store_type'] = tenant.last_import_store_type || ImportItem.last.try(:store).try(:store_type)
        Apartment::Tenant.switch!
      end

      def retrieve_plan_data(tenant_name, tenant_hash)
        plan_data = get_subscription_data(tenant_name, 'index')
        tenant_hash['start_day'] = plan_data['start_day']
        tenant_hash['plan'] = plan_data['plan']
        tenant_hash['amount'] = plan_data['amount']
        tenant_hash['progress'] = plan_data['progress']
        tenant_hash['transaction_errors'] = plan_data['transaction_errors']
        tenant_hash['stripe_url'] = plan_data['customer_id']
        tenant_hash['url'] = tenant_name + '.' + ENV['FRONTEND_HOST']
      end

      def retrieve_shipping_data(tenant_name, tenant_hash)
        get_shipping_data = Groovepacker::Dashboard::Stats::ShipmentStats.new
        access_restrictions = @access_restrictions_per_tenant[tenant_name]
        shipping_data = get_shipping_data.get_shipment_stats(tenant_name, true)
        tenant_hash['total_shipped'] = shipping_data['shipped_current']
        tenant_hash['shipped_last'] = shipping_data['shipped_last']
        tenant_hash['max_allowed'] = shipping_data['max_allowed']
        tenant_hash['average_shipped'] = shipping_data['average_shipped']
        tenant_hash['average_shipped_last'] = shipping_data['average_shipped_last']
        tenant_hash['shipped_last6'] = shipping_data['shipped_last6']
      end

      def get_access_restrictions_for_all_tenants
        @access_restrictions_per_tenant = Hash.new([])
        return if @tenant_names.blank?

        query = "(select *,'#{@tenant_names.first}' as 'tenant_name' from #{@tenant_names.first}.access_restrictions ORDER BY created_at)"

        query = @tenant_names.reduce(query) do |_query, t_name|
          _query += " union (select *,'#{t_name}' as 'tenant_name' from #{t_name}.access_restrictions ORDER BY created_at)"
        end

        return unless query.present?

        @access_restrictions_per_tenant.merge!(
          AccessRestriction.find_by_sql(query).group_by(&:tenant_name)
        )
      end

      def construct_query_and_get_result(params, search, sort_key, sort_order, query_add)
        result = result_hash
        current_tenant = Apartment::Tenant.current
        Apartment::Tenant.switch!
        base_query = build_query(search, sort_key, sort_order)

        result['tenants'] = Tenant.find_by_sql(base_query + query_add)
        result['count'] = if params[:select_all] || params[:inverted]
                            result['tenants'].length
                          else
                            Tenant.count_by_sql('SELECT count(*) as count from(' + base_query + ') as tmp')
                          end
        Apartment::Tenant.switch!(current_tenant)
        result
      end

      def build_query(search, sort_key, sort_order)
        'SELECT tenants.id as id, tenants.name as name, tenants.scheduled_import_toggle as scheduled_import_toggle, tenants.note as note, tenants.is_modified as is_modified, tenants.updated_at as updated_at, tenants.created_at as created_at, subscriptions.subscription_plan_id as plan, subscriptions.stripe_customer_id as stripe_url, tenants.last_import_store_type as last_import_store_type
          FROM tenants LEFT JOIN subscriptions ON (subscriptions.tenant_id = tenants.id)
            WHERE
              (
                tenants.name like ' + search + ' OR subscriptions.subscription_plan_id like ' + search + ' OR tenants.last_import_store_type like ' + search + '
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
        subscription_result['plan'] = begin
                                        construct_plan_hash.key(sub_plan_id) || sub_plan_id.capitalize.tr('-', ' ')
                                      rescue StandardError
                                        nil
                                      end # get_plan_name(sub_plan_id)
        subscription_result['plan_id'] = sub_plan_id
        subscription_result['amount'] = format('%.2f', (subscription.amount * 100).round / 100.0 / 100.0) if subscription.amount
        subscription_result['start_day'] = subscription.created_at.strftime('%d %b')
        subscription_result['customer_id'] = subscription.stripe_customer_id if subscription.stripe_customer_id
        subscription_result['email'] = subscription.email if subscription.email
        subscription_result['progress'] = subscription.progress
        subscription_result['transaction_errors'] = subscription.transaction_errors if subscription.transaction_errors
        subscription_result['customer_subscription_id'] = subscription.customer_subscription_id
      end

      def create_new_plan_and_assign(tenant)
        @updated_in_stripe = true
        plan_info = new_plan_info(tenant)
        plan_id = plan_info['plan_id']
        existing_plan = get_plan_info(@subscription_info[:plan_id])['plan_info']
        amount = @subscription_info[:amount].to_i * 100
        create_plan(amount,
                    @subscription_info[:interval] || @subscription.interval,
                    plan_info['plan_name'],
                    'usd',
                    plan_id)
        begin
          update_stripe_subscription(plan_id)
        rescue StandardError
          nil
        end
        begin
          update_subscription_item(plan_id, existing_plan)
        rescue StandardError
          nil
        end
        begin
          update_annual_subscription(plan_id)
        rescue StandardError
          nil
        end
        update_app_subscription(plan_id, amount, @subscription_info[:interval]) if @updated_in_stripe == true
        begin
          (existing_plan.delete unless construct_plan_hash[@subscription_info[:plan]])
        rescue StandardError
          nil
        end
      end

      def update_stripe_subscription(plan_id)
        @customer = get_stripe_customer(@subscription.stripe_customer_id)
        plan = begin
                 Stripe::Plan.retrieve(plan_id)
               rescue StandardError
                 nil
               end
        if @customer
          subscription = Stripe::Subscription.retrieve(@subscription.customer_subscription_id)
          @trial_end_time = subscription.trial_end
          customer_subscription = subscription
          if @trial_end_time && (@trial_end_time > Time.current.to_i)
            begin
              Stripe::Subscription.update(customer_subscription.id, plan: plan, trial_end: @trial_end_time, proration_behavior: 'none')
              @updated_in_stripe = true
            rescue Exception => e
              Rollbar.error(e, e.message, Apartment::Tenant.current)
              @updated_in_stripe = false
            end
          else
            begin
              if customer_subscription.items.count > 1
                Stripe::SubscriptionItem.create(subscription: customer_subscription.id, plan: plan, proration_behavior: 'create_prorations')
                remove_existing_plans(customer_subscription, plan_id)
              else
                Stripe::Subscription.update(customer_subscription.id, plan: plan, proration_behavior: 'create_prorations')
              end
              @updated_in_stripe = true
            rescue Exception => e
              Rollbar.error(e, e.message, Apartment::Tenant.current)
              @updated_in_stripe = false
            end
          end
        end
      end

      def remove_existing_plans(subscription, active_plan_id)
        return unless active_plan_id.match?(/#{Apartment::Tenant.current}-\d+/)

        active_subscription_items = {}
        subscription.refresh.items.data.each do |item|
          active_subscription_items[item.id] = item.plan.id
        end

        items_to_remove = active_subscription_items.select do |_item_id, plan_id|
          plan_id.match?(/#{Apartment::Tenant.current}-\d+/) && plan_id != active_plan_id
        end

        items_to_remove.keys.each do |item_id|
          Stripe::SubscriptionItem.delete(item_id)
        end
      end

      def update_subscription_item(plan_id, existing_plan)
        @customer = get_stripe_customer(@subscription.stripe_customer_id)
        if @customer
          subscription = Stripe::Subscription.retrieve(@subscription.customer_subscription_id)
          if subscription.items.count >= 2
            @trial_end_time = subscription.trial_end
            subscription.items.data.each do |item|
              next unless item.plan['id'] == existing_plan.id

              proration_behavior = @trial_end_time && (@trial_end_time > Time.current.to_i) ? 'none' : 'create_prorations'
              begin
                Stripe::SubscriptionItem.update(item.id, plan: plan_id, proration_behavior: proration_behavior)
                @updated_in_stripe = true
              rescue Exception => e
                Rollbar.error(e, e.message, Apartment::Tenant.current)
                @updated_in_stripe = false
              end
            end
          end
        end
      end

      def update_annual_subscription(plan_id)
        if @customer
          subscription = Stripe::Subscription.retrieve(@subscription.customer_subscription_id)
          if @customer.subscriptions.count >= 2 && subscription.plan.interval == 'year'
            if @trial_end_time && (@trial_end_time > Time.current.to_i)
              begin
                Stripe::Subscription.update(subscription.id, plan: plan_id, trial_end: @trial_end_time, proration_behavior: 'none')
                @updated_in_stripe = true
              rescue Exception => e
                Rollbar.error(e, e.message, Apartment::Tenant.current)
                @updated_in_stripe = false
              end
            else
              begin
                Stripe::Subscription.update(subscription.id, plan: plan_id, proration_behavior: 'create_prorations')
                @updated_in_stripe = true
              rescue Exception => e
                Rollbar.error(e, e.message, Apartment::Tenant.current)
                @updated_in_stripe = false
              end
            end
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
          tenant_hash['last_activity']['most_recent_login'] = most_recent_login(tenant_name)
          tenant_hash['last_activity']['most_recent_scan'] = most_recent_scan(tenant_name)
          tenant_hash['most_recent_activity'] = most_recent_login(tenant_name)['date_time']
          last_login = tenant_hash['last_activity']['most_recent_login']
          last_scan =  tenant_hash['last_activity']['most_recent_scan']
          begin
            (tenant_hash['last_activity']['most_recent_scan']['user'] = tenant_hash['last_activity']['most_recent_scan']['user'].username)
          rescue StandardError
            nil
          end
          if last_login['date_time'].to_i < last_scan['date_time'].to_i
            tenant_hash['last_activity']['most_recent_login'] = most_recent_scan(tenant_name)
            tenant_hash['last_activity']['most_recent_login']['user'] = tenant_hash['last_activity']['most_recent_login']['user'].username
            tenant_hash['most_recent_activity'] = most_recent_scan(tenant_name)
            tenant_hash['latest_activity'] = last_scan['date_time']
          else
            tenant_hash['latest_activity'] = last_login['date_time']
          end
          check_split_or_production
        rescue StandardError => e
          tenant_hash['most_recent_activity'] = nil
          tenant_hash['last_activity'] = nil
          check_split_or_production
        end
        Apartment::Tenant.switch!(current_tenant)
      end

      def check_split_or_production
        Apartment::Tenant.switch!
        db_name = Apartment::Tenant.current
        db_name.include?('split') ? Apartment::Tenant.switch!('scadmintools') : Apartment::Tenant.switch!('admintools')
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

      def most_recent_login(tenant_name)
        most_recent_login_data = {}
        @user = @recent_login_per_tenant[tenant_name].first
        if @user
          most_recent_login_data['date_time'] = @user.current_sign_in_at
          most_recent_login_data['user'] = @user.username
        end
        most_recent_login_data
      end

      def recent_login_all_tenants
        @recent_login_per_tenant = Hash.new([])

        query = @tenant_names.reduce('') do |_query, t_name|
          _query += %(\
            #{'union' if _query.present?} (select *,'#{t_name}' as 'tenant_name' \
            from #{t_name}.users \
            where(username!='gpadmin' and current_sign_in_at is not null) \
            ORDER BY current_sign_in_at desc LIMIT 1)\
          )
        end

        return unless query.present?

        @recent_login_per_tenant.merge!(
          User.find_by_sql(query).group_by(&:tenant_name)
        )
      end

      def most_recent_scan(tenant_name)
        most_recent_scan_data = {}

        @order = @latest_scanned_orders_per_tenant[tenant_name].first

        if @order
          most_recent_scan_data['date_time'] = @order.scanned_on
          most_recent_scan_data['user'] = begin
                                            @latest_scanned_order_packing_user_per_tenant[tenant_name].first
                                          rescue StandardError
                                            nil
                                          end
        end
        most_recent_scan_data
      end

      def latest_scanned_order_for_all_tenants
        @latest_scanned_orders_per_tenant = Hash.new([])

        query = @tenant_names.reduce('') do |_query, t_name|
          _query += %(\
            #{'union' if _query.present?} (select *,'#{t_name}' as 'tenant_name' \
            from #{t_name}.orders \
            where(status='scanned') ORDER BY scanned_on desc LIMIT 1)\
          )
        end

        return unless query.present?

        @latest_scanned_orders_per_tenant.merge!(
          Order.find_by_sql(query).group_by(&:tenant_name)
        )
      end

      def latest_scanned_order_packing_user_for_all_tenants
        @latest_scanned_order_packing_user_per_tenant = Hash.new([])

        query = @tenant_names.reduce('') do |_query, t_name|
          user_id = @latest_scanned_orders_per_tenant[t_name].first.try(:packing_user_id)

          next _query unless user_id

          _query += %(\
            #{'union' if _query.present?} (select *,'#{t_name}' as 'tenant_name' \
            from #{t_name}.users \
            where(id=#{user_id}))\
          )
        end

        return unless query.present?

        @latest_scanned_order_packing_user_per_tenant.merge!(
          User.find_by_sql(query).group_by(&:tenant_name)
        )
      end

      def rec_subscription(tenant, subscription_result)
        if tenant
          @subscription = tenant.subscription
          if @subscription
            retrieve_subscription_result(subscription_result, @subscription)
          else
            parent_tenant = find_parent_tenant(tenant.id)
            rec_subscription(parent_tenant, subscription_result)
          end
        end
      end

      def find_parent_tenant(id)
        @parent_tenants ?
        @parent_tenants.find { |pt| pt.duplicate_tenant_id.eql?(id) } :
        Tenant.find_by_duplicate_tenant_id(id)
      end

      def parent_tenant_for_all_tenants
        @parent_tenants = Tenant.where(duplicate_tenant_id: @tenants.map(&:id))
      end

      def sort_param(params)
        return 'most_recent_activity' if params[:sort] == 'last_activity'

        params[:sort]
      end

      def update_parent(tenant)
        parent = Tenant.find_by_duplicate_tenant_id(tenant.id)
        parent&.update_attribute(:duplicate_tenant_id, nil)
      end
    end
  end
end
