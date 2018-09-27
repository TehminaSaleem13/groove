module UsersHelper
  include Groovepacker::Tenants

  def update_role(user_role, role)

    if current_user.can? 'add_edit_users'
      if role.nil?
        role = Hash.new
      end
      if role['make_super_admin'].nil? ||
        (role['make_super_admin'] && !current_user.can?('make_super_admin'))
        role['make_super_admin'] = false
      end

      if role['make_super_admin']
        role['add_edit_order_items'] = true
      end

      if role['add_edit_order_items'].nil?
        role['add_edit_order_items'] = false
      end 

      #Scanpack is hard coded to be true
      role['access_scanpack'] = true

      #user details permissions
      user_role.make_super_admin = role['make_super_admin']
      user_role.add_edit_users = (role['make_super_admin'] || (!role['add_edit_users'].nil? && role['add_edit_users']))

      #order details
      user_role.add_edit_order_items = role['add_edit_order_items']
      user_role.import_orders = (role['add_edit_order_items'] || (!role['import_orders'].nil? && role['import_orders']))
      user_role.change_order_status = (role['add_edit_order_items'] || (!role['change_order_status'].nil? && role['change_order_status']))
      user_role.create_edit_notes = (role['add_edit_order_items'] || (!role['create_edit_notes'].nil? && role['create_edit_notes']))

      # order exceptions
      user_role.view_packing_ex = (role['make_super_admin'] || (!role['view_packing_ex'].nil? && role['view_packing_ex']))
      user_role.create_packing_ex = (role['make_super_admin'] || (!role['create_packing_ex'].nil? && role['create_packing_ex']))
      user_role.edit_packing_ex = (role['make_super_admin'] || (!role['edit_packing_ex'].nil? && role['edit_packing_ex']))

      #product details
      user_role.add_edit_products = (role['make_super_admin'] || (!role['add_edit_products'].nil? && role['add_edit_products']))
      user_role.delete_products = (role['make_super_admin'] || (!role['delete_products'].nil? && role['delete_products']))
      user_role.import_products = (role['make_super_admin'] || (!role['import_products'].nil? && role['import_products']))

      #User access.
      user_role.access_scanpack = (role['make_super_admin'] || (!role['access_scanpack'].nil? && role['access_scanpack']))
      user_role.access_orders = (role['make_super_admin'] || (!role['access_orders'].nil? && role['access_orders']))
      user_role.access_products = (role['make_super_admin'] || (!role['access_products'].nil? && role['access_products']))
      user_role.access_settings = (role['make_super_admin'] || (!role['access_settings'].nil? && role['access_settings']))

      #System settings permission
      user_role.edit_general_prefs = (role['make_super_admin'] || (!role['edit_general_prefs'].nil? && role['edit_general_prefs']))
      user_role.edit_scanning_prefs = (role['make_super_admin'] || (!role['edit_scanning_prefs'].nil? && role['edit_scanning_prefs']))
      user_role.add_edit_stores = (role['make_super_admin'] || (!role['add_edit_stores'].nil? && role['add_edit_stores']))
      user_role.create_backups = (role['make_super_admin'] || (!role['create_backups'].nil? && role['create_backups']))
      user_role.restore_backups = (role['make_super_admin'] || (!role['restore_backups'].nil? && role['restore_backups']))

      user_role.save
    end
    return user_role
  end

  # def update_plan_amount type
  #   tenant = Tenant.find_by_name(Apartment::Tenant.current)
  #   @subscription = tenant.subscription
  #   amount = @subscription.amount.to_f/100
  #   role_id = Role.find_by_name("Super Super Admin").try(:id)
  #   users_count = User.where("active = ? and is_deleted = ? and role_id != ?", true, false, role_id).count
  #   if users_count > AccessRestriction.last.num_users && type == 'add'
  #     amount = amount + 50
  #     set_subscription_info(amount)
  #     create_stripe_plan(tenant)
  #   end
  # end

  def set_subscription_info amount
    @subscription_info = { }
    @subscription_info[:subscription_info] = { 
      amount: amount,
      plan_id: @subscription.subscription_plan_id,
      interval: @subscription.interval,
      customer_subscription_id: @subscription.customer_subscription_id,
      stripe_customer_id: @subscription.stripe_customer_id,
      stripe_customer_id: @subscription.stripe_customer_id
    }
  end

  def create_stripe_plan tenant
    helper = Groovepacker::Tenants::Helper.new
    helper.update_subscription_plan(tenant, @subscription_info)
  end

  def check_for_removal params, access_restriction,tenant
    if params[:users].to_i < access_restriction.num_users && params[:is_annual] == "false"
      users = access_restriction.num_users -  params[:users].to_i
      if access_restriction.added_through_ui == 0 
        StripeInvoiceEmail.remove_user_request_email(tenant, users).deliver
        return true
      else
        if access_restriction.added_through_ui < users
          rm_user = users - access_restriction.added_through_ui
          params[:users] = params[:users].to_i + rm_user
          params[:amount] = params[:users].to_i * 50  
          StripeInvoiceEmail.remove_user_request_email(tenant, rm_user).deliver
          access_restriction.update_attributes(added_through_ui: 0)
        end
        ui_users = access_restriction.added_through_ui - users if access_restriction.added_through_ui != 0
        access_restriction.update_attributes(added_through_ui: ui_users) if access_restriction.added_through_ui != 0
        access_restriction.update_attributes(num_users: params[:users])
        set_subscription_info(params[:amount])
        create_stripe_plan(tenant)
        return false
      end
    end
  end
end
