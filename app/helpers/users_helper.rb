# frozen_string_literal: true

module UsersHelper
  include Groovepacker::Tenants

  def update_role(user_role, role)
    if current_user.can? 'add_edit_users'
      role ||= {}

      if role['make_super_admin'].nil? ||
         (role['make_super_admin'] && !current_user.can?('make_super_admin'))
        role['make_super_admin'] = false
      end

      role['add_edit_order_items'] = true if role['make_super_admin']

      role['add_edit_order_items'] = false if role['add_edit_order_items'].nil?

      # Scanpack is hard coded to be true
      role['access_scanpack'] = true

      # user details permissions
      user_role.make_super_admin = role['make_super_admin']
      user_role.add_edit_users = (role['make_super_admin'] || (!role['add_edit_users'].nil? && role['add_edit_users']))

      # order details
      user_role.add_edit_order_items = role['add_edit_order_items']
      user_role.import_orders = (role['add_edit_order_items'] || (!role['import_orders'].nil? && role['import_orders']))
      user_role.change_order_status = (role['add_edit_order_items'] || (!role['change_order_status'].nil? && role['change_order_status']))
      user_role.create_edit_notes = (role['add_edit_order_items'] || (!role['create_edit_notes'].nil? && role['create_edit_notes']))

      # order exceptions
      user_role.view_packing_ex = (role['make_super_admin'] || (!role['view_packing_ex'].nil? && role['view_packing_ex']))
      user_role.create_packing_ex = (role['make_super_admin'] || (!role['create_packing_ex'].nil? && role['create_packing_ex']))
      user_role.edit_packing_ex = (role['make_super_admin'] || (!role['edit_packing_ex'].nil? && role['edit_packing_ex']))

      # product details
      if role['add_edit_products']
        user_role.add_edit_products = (!role['add_edit_products'].nil? && role['add_edit_products'])
        unless role['edit_product_location']
          user_role.edit_product_location = (!role['edit_product_location'].nil? && !role['edit_product_location'])
        end
        unless role['edit_product_quantity']
          user_role.edit_product_quantity = (!role['edit_product_quantity'].nil? && !role['edit_product_quantity'])
        end
      else
        user_role.add_edit_products = (!role['add_edit_products'].nil? && role['add_edit_products'])
        user_role.edit_product_location = (!role['edit_product_location'].nil? && role['edit_product_location'])
        user_role.edit_product_quantity = (!role['edit_product_quantity'].nil? && role['edit_product_quantity'])
      end
      user_role.delete_products = (role['make_super_admin'] || (!role['delete_products'].nil? && role['delete_products']))
      user_role.import_products = (role['make_super_admin'] || (!role['import_products'].nil? && role['import_products']))

      # User access.
      user_role.access_scanpack = (role['make_super_admin'] || (!role['access_scanpack'].nil? && role['access_scanpack']))
      user_role.access_orders = (role['make_super_admin'] || (!role['access_orders'].nil? && role['access_orders']))
      user_role.access_products = (role['make_super_admin'] || (!role['access_products'].nil? && role['access_products']))
      user_role.access_settings = (role['make_super_admin'] || (!role['access_settings'].nil? && role['access_settings']))

      # System settings permission
      user_role.edit_general_prefs = (role['make_super_admin'] || (!role['edit_general_prefs'].nil? && role['edit_general_prefs']))
      user_role.edit_scanning_prefs = (role['make_super_admin'] || (!role['edit_scanning_prefs'].nil? && role['edit_scanning_prefs']))
      user_role.add_edit_stores = (role['make_super_admin'] || (!role['add_edit_stores'].nil? && role['add_edit_stores']))
      user_role.create_backups = (role['make_super_admin'] || (!role['create_backups'].nil? && role['create_backups']))
      user_role.restore_backups = (role['make_super_admin'] || (!role['restore_backups'].nil? && role['restore_backups']))

      user_role.save
    end
    user_role
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

  def set_subscription_info(amount)
    @subscription_info = {}
    @subscription_info[:subscription_info] = {
      amount: amount,
      plan_id: @subscription.subscription_plan_id,
      interval: @subscription.interval,
      customer_subscription_id: @subscription.customer_subscription_id,
      customer_id: @subscription.stripe_customer_id
    }
  end

  def create_stripe_plan(tenant)
    helper = Groovepacker::Tenants::Helper.new
    helper.update_subscription_plan(tenant, @subscription_info)
  end

  def check_for_removal(params, access_restriction, tenant)
    if params[:users].to_i < access_restriction.num_users && params[:is_annual] == 'false'
      users = access_restriction.num_users - params[:users].to_i
      if access_restriction.added_through_ui == 0
        StripeInvoiceEmail.remove_user_request_email(tenant, users).deliver
        tenant.activity_log = "#{Time.current.strftime('%Y-%m-%d  %H:%M')} Request for User Remove: #{users} user wants to remove from plan. \n" + tenant.activity_log.to_s
        tenant.save!
        return true
      else
        if access_restriction.added_through_ui < users
          rm_user = users - access_restriction.added_through_ui
          params[:users] = params[:users].to_i + rm_user
          params[:amount] = params[:users].to_i * 50
          tenant.activity_log = "#{Time.current.strftime('%Y-%m-%d  %H:%M')} Request for User Remove: #{rm_user} user wants to remove from plan. \n" + tenant.activity_log.to_s
          tenant.save!
          StripeInvoiceEmail.remove_user_request_email(tenant, rm_user).deliver
          access_restriction.update_attributes(added_through_ui: 0)
        end
        ui_users = access_restriction.added_through_ui - users if access_restriction.added_through_ui != 0
        access_restriction.update_attributes(added_through_ui: ui_users) if access_restriction.added_through_ui != 0
        StripeInvoiceEmail.user_remove_notification(tenant, access_restriction, params[:users]).deliver
        tenant.activity_log = "#{Time.current.strftime('%Y-%m-%d  %H:%M')} User Removed: From #{access_restriction.num_users} user plan to #{params[:users]} user and amount is #{params[:amount]} \n" + tenant.activity_log.to_s
        tenant.save!
        access_restriction.update_attributes(num_users: params[:users])
        set_subscription_info(params[:amount])
        create_stripe_plan(tenant)
        return false
      end
    end
  end

  def remove_user(params, access_restriction, tenant)
    if params[:users].to_i < access_restriction.num_users && params[:is_annual] == 'false'
      users = access_restriction.num_users - params[:users].to_i
      ui_users = access_restriction.added_through_ui - users if access_restriction.added_through_ui != 0
      access_restriction.update_attributes(added_through_ui: ui_users) if access_restriction.added_through_ui != 0
      StripeInvoiceEmail.user_remove_notification(tenant, access_restriction, params[:users]).deliver
      tenant.activity_log = "#{Time.current.strftime('%Y-%m-%d  %H:%M')} User Removed: From #{access_restriction.num_users} user plan to #{params[:users]} user and amount is #{params[:amount]} \n" + tenant.activity_log.to_s
      tenant.save!
      access_restriction.update_attributes(num_users: params[:users])
      set_subscription_info(params[:amount])
      create_stripe_plan(tenant)
      false
    end
  end

  def assign_user_attributes(params)
    @user.password = params[:password] if !params[:password].nil? && params[:password] != ''
    @user.username = params[:username]
    @user.email = params[:email]
    @user.other = params[:other] unless params[:other].nil?
    @user.password_confirmation = params[:conf_password] if !params[:conf_password].nil? && params[:conf_password] != ''
    params[:active] = false if params[:active].blank?

    @user.active = params[:active]

    @user.name = params[:name].blank? ? params[:username] : params[:name]
    @user.last_name = params[:last_name]
    username_change = @user.username_change

    @user.view_dashboard = params[:view_dashboard] unless params[:view_dashboard].nil?

    @user.dashboard_switch = params[:dashboard_switch] unless params[:dashboard_switch].nil?

    @user.confirmation_code = params[:confirmation_code]
    @user.custom_field_one = params[:custom_field_one]
    @user.custom_field_two = params[:custom_field_two]
    @user.warehouse_postcode = params[:warehouse_postcode]
    @user.packing_slip_size = params[:packing_slip_size]
    @user.override_pass_scanning = params[:override_pass_scanning]
  end

  def assign_user_role(params)
    if params[:role].nil? || params[:role]['id'].nil?
      user_role = Role.find_by_name("role_#{@user.id}")
      if user_role.nil?
        user_role = Role.new
        user_role.custom = true
        user_role.display = false
        user_role.name = "role_#{@user.id}"
      end
      user_role
    else
      user_role = Role.where(id: params[:role]['id']).last
    end
  end

  def set_user_dashboard(params, result, user_role)
    # Make sure we have at least one super admin
    if current_user.can?('make_super_admin') && !params[:role]['make_super_admin'] &&
       User.where(is_deleted: false).eager_load(:role).where('roles.make_super_admin = 1').length <= 2 && !@user.role.nil? && @user.role.make_super_admin
      result['status'] = false
      result['messages'].push('The app needs at least one super admin at all times')
    elsif !current_user.can?('make_super_admin') &&
          ((params[:role]['make_super_admin'] && (@user.role.nil? || !@user.role.make_super_admin)) ||
            (!params[:role]['make_super_admin'] && !@user.role.nil? && @user.role.make_super_admin))
      result['status'] = false
      result['messages'].push('You can not grant or revoke super admin privileges.')
    else
      user_role = update_role(user_role, params[:role]) if user_role.custom && !user_role.display
      update_label_related_settings(user_role, params[:role])
      if user_role.name != @user.role.try(:name) && @new_user != true
        @user.view_dashboard = case user_role.name
                               when 'Scan & Pack User'
                                 'packer_dashboard'
                               when 'Manager'
                                 'packer_dashboard'
                               when 'Admin'
                                 'admin_dashboard'
                               when 'Super Admin'
                                 'admin_dashboard_with_packer_stats'
                               else
                                 begin
                                   user_role.users.last.try(:view_dashboard)
                                 rescue StandardError
                                   'packer_dashboard'
                                 end
                               end
      end
      @user.role = user_role
    end
  end

  def update_label_related_settings(user_role, role)
    user_role.edit_shipping_settings = (role['make_super_admin'] || (!role['edit_shipping_settings'].nil? && role['edit_shipping_settings']))
    user_role.edit_visible_services = (role['make_super_admin'] || (!role['edit_visible_services'].nil? && role['edit_visible_services']))
    user_role.add_edit_shortcuts = (role['make_super_admin'] || (!role['add_edit_shortcuts'].nil? && role['add_edit_shortcuts']))
    user_role.add_edit_dimension_presets = (role['make_super_admin'] || (!role['add_edit_dimension_presets'].nil? && role['add_edit_dimension_presets']))
  end

  def set_and_return_user_info(result)
    if @user.save
      result['user'] = @user.attributes
      result['user']['role'] = @user.role.attributes
      result['user']['current_user'] = current_user
      if @new_user && !Rails.env.test?
        tenant_name = Apartment::Tenant.current
        send_user_info_obj = SendUsersInfo.new
        # send_user_info_obj.build_send_users_stream(tenant_name)
        send_user_info_obj.delay(run_at: 1.seconds.from_now, queue: 'send_users_info_#{tenant_name}', priority: 95).build_send_users_stream(tenant_name)
      else
        set_custom_fields
        send_user_info_data = SendUsersInfo.new
        tenant_name = Apartment::Tenant.current
        user_data = { username: @user.username, packing_user_id: @user.id, active: @user.active, first_name: @user.name, last_name: @user.last_name, custom_field_one_key: @custom_field_one_key, custom_field_one_value: @custom_field_one_value, custom_field_two_key: @custom_field_two_key, custom_field_two_value: @custom_field_two_value }
        send_user_info_data.delay(run_at: 1.seconds.from_now, queue: 'update_users_info_#{tenant_name}', priority: 95).update_gl_user(user_data, tenant_name) if user_data[:packing_user_id].present?
      end
    else
      result['status'] = false
      result['messages'] = @user.errors.full_messages
    end
  end

  def retrieve_or_create_new_user(params)
    if params[:id].nil?
      @user = User.new
      @new_user = true
    else
      @user = User.find(params[:id])
    end
  end

  def save_or_update_user(result, params)
    if result['status']
      assign_user_attributes(params)

      user_role = assign_user_role(params)

      if user_role.nil?
        result.status = false
        result['messages'].push('Invalid user Role')
      else
        set_user_dashboard(params, result, user_role)
        role = @user.role
        role.import_orders = params[:role][:import_orders]
        role.save
      end
      set_and_return_user_info(result)
    end
  end

  def create_existing_role(params, result)
    if params[:role].nil?
      result['status'] = false
      result['messages'].push('No role data sent')
    elsif params[:role]['new_name'].blank? || params[:role]['new_name'][0, 5] == 'role_' || !Role.find_by_name(params[:role]['new_name']).nil?
      result['status'] = false
      result['messages'].push('Role name invalid. Please input a valid Role name')
    else
      if params[:role]['id'].nil?
        user_role = Role.find_by_name("role_#{params[:id]}")
        user_role = Role.new if user_role.nil?
      else
        user_role = Role.find_by_id(params[:role]['id'])
      end
      user_role.custom = true
      user_role.display = true
      user_role.name = params[:role]['new_name']
      user_role = update_role(user_role, params[:role])
      result['role'] = user_role
      user = User.find(params[:id])
      if user.nil?
        result['status'] = false
        result['messages'].push('Role saved but could not apply to user. Please click save and close to apply manually')
      else
        user.role = user_role
        user.save
      end
    end
  end

  def delete_existing_role(params, result)
    if params[:role].nil? || params[:role]['id'].nil?
      result['status'] = false
      result['messages'].push('No role data sent')
    else
      if params[:role]['id'].nil?
        user_role = Role.find_by_name("role_#{@user.id}")
        user_role = Role.new if user_role.nil?
      else
        user_role = Role.find_by_id(params[:role]['id'])
      end

      scan_pack_role = Role.find_by_name('Scan & Pack User')
      User.where(role_id: user_role.id).update_all(role_id: scan_pack_role.id)
      user_role.destroy

      result['role'] = scan_pack_role
    end
  end

  def create_duplicate_user(result, user)
    @user = User.find(user['id'])
    # @newuser = User.new
    @newuser = @user.dup
    index = 0
    @newuser.username = @user.username + '(duplicate' + index.to_s + ')'
    @userslist = User.where(username: @newuser.username)
    begin
      index += 1
      @newuser.username = @user.username + '(duplicate' + index.to_s + ')'
      @userslist = User.where(username: @newuser.username)
    end while (!@userslist.nil? && !@userslist.empty?)

    @newuser.password = @user.password
    @newuser.password_confirmation = @user.password_confirmation
    @newuser.confirmation_code = @user.confirmation_code + '1'
    @newuser.last_sign_in_at = ''
    unless @newuser.save(validate: false)
      result['status'] = false
      result['messages'] = @newuser.errors.full_messages
    end
    tenant_name = Apartment::Tenant.current
    send_user_info_obj = SendUsersInfo.new
    send_user_info_obj.delay(run_at: 1.seconds.from_now, queue: 'send_users_info_#{tenant_name}', priority: 95).build_send_users_stream(tenant_name)
  end

  def delete_existing_user(result, users, user_names)
    user_count = User.where(active: true, is_deleted: false).count
    super_admin_user = Role.find_by_name('Super Admin').users.where(active: true, is_deleted: false)
    super_admin_user_count = super_admin_user.count
    params['_json'].each do |user|
      next if user['id'] == current_user.id

      @user = User.find(user['id'])
      if (user_count > 1 && @user.role.name != 'Super Admin') || (super_admin_user[0].try(:role).try(:name) == @user.role.name && super_admin_user_count >= 1)
        if super_admin_user_count == 1 && super_admin_user.map(&:id).include?(@user.id)
          result['status'] = false
          result['messages'].push('You must have at least one SuperAdmin user on the account.')
        else
          super_admin_user_count -= 1 if super_admin_user.any? && super_admin_user[0].role.name == @user.role.name
          user_names << { 'id' => @user.id, 'username' => @user.username }
          @user.username += '-' + Random.rand(10_000_000..99_999_999).to_s
          @user.is_deleted = true
          @user.active = false
          @user.save
          if @user.present?
            begin
              HTTParty.post("#{ENV['GROOV_ANALYTIC_URL']}/users/delete_user",
                            query: { username: @user.username, packing_user_id: @user.id },
                            headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current })
            rescue StandardError
              nil
            end
          end
          users << @user
        end
      else
        result['status'] = false
        result['messages'].push('You must have at least one SuperAdmin user on the account.')
      end
    end
  end

  def send_email_reset_instruction(user, result, admin_email)
    if user.email.blank?
      admin_user = User.find_by_email(admin_email)
      result[:msg] = "A password recovery link has been sent to #{admin_user.username} at #{admin_email}"
      user.update_attribute(:email, admin_email)
      email = user.send_reset_password_instructions
      user.update_attribute(:email, '')
    else
      result[:msg] = "A password reset link has been emailed to the address associated with your user account: #{user.email}"
      email = user.send_reset_password_instructions
    end
    user.reset_token = email
    user.save!
    result[:code] = 1
  end

  def check_and_create_duplicate_user(user, result)
    if User.can_create_new?
      create_duplicate_user(result, user)
    else
      result['status'] = false
      result['messages'] = 'You have reached the maximum limit of number of users for your subscription.'
    end
  end

  def check_for_invalid_password(params, result)
    if !params[:password].nil? && params[:password] != '' && (params[:conf_password].blank? || params[:conf_password].length < 6)
      result['status'] = false
      result['messages'].push('Password and Confirm Password can not be less than 6 characters')
    end
  end

  def get_subscription_info
    result = {}
    result['status'] = true
    result['no_of_users'] = AccessRestriction.last.num_users
    result['added_through_ui'] = AccessRestriction.last.added_through_ui
    result ['total_users'] = User.where(is_deleted: false).count
    tenant = Tenant.find_by_name(Apartment::Tenant.current)
    subscription = tenant.subscription
    result['amount'] = begin
                         (subscription.amount.to_f / 100)
                       rescue StandardError
                         0
                       end
    respond_to do |format|
      format.json { render json: result }
    end
  end

  def fetch_invoices(customer_id)
    Rails.cache.fetch("#{customer_id}-invoices", expires_in: 5.minutes) do
      invoices = Stripe::Invoice.list({
        customer: customer_id,
        created: { gte: 1.year.ago.to_i },
        limit: 30
      })

      invoices.data.map do |invoice|
        {
          invoice_number: invoice.number,
          customer_email: invoice.customer_email,
          created: Time.zone.at(invoice.created).strftime("%d %b %Y, %H:%M"),
          pdf_url: invoice.invoice_pdf
        }
      end
    end
  end
end
