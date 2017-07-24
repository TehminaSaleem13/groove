class UsersController < ApplicationController
  before_filter :groovepacker_authorize! , except: [:get_user_email,:update_password]
  include UsersHelper

  def index
    @users = User.where('username != ? and is_deleted = ?', 'gpadmin', false)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @users, :only => [:id, :username, :last_sign_in_at, :active], :include => :role }
    end
  end


  def createUpdateUser
    result = {}
    result['status'] = true
    result['messages'] = []

    if current_user.can? 'add_edit_users'
      new_user = false
      if params[:id].nil?
        if User.can_create_new?
          @user = User.new
          new_user = true
        else
          result['status'] = false
          result['messages'].push('You have reached the maximum limit of number of users for your subscription.')
        end
      else
        @user = User.find(params[:id])
      end

      if !params[:password].nil? && params[:password] != '' && (params[:conf_password].blank? || params[:conf_password].length < 6)
        result['status'] = false
        result['messages'].push('Password and Confirm Password can not be less than 6 characters')
      end
      if result['status']
        @user.password = params[:password] if !params[:password].nil? && params[:password] != ''
        @user.username = params[:username]
        @user.email = params[:email]
        @user.other = params[:other] if !params[:other].nil?
        @user.password_confirmation = params[:conf_password] if !params[:conf_password].nil? && params[:conf_password] != ''
        if params[:active].blank?
          params[:active] = false
        end
        
        @user.active = params[:active]
        if params[:name].blank?
          @user.name = params[:username]
        else
          @user.name = params[:name]
        end
        username_change = @user.username_change
        unless params[:view_dashboard].nil?
          @user.view_dashboard = params[:view_dashboard]
        end

        @user.confirmation_code = params[:confirmation_code]

        if params[:role].nil? || params[:role]['id'].nil?
          user_role = Role.find_by_name("role_#{@user.id}")
          if user_role.nil?
            user_role = Role.new
            user_role.custom = true
            user_role.display = false
            user_role.name = "role_#{@user.id}"
          end
        else
          user_role = Role.find_by_id(params[:role]['id'])
        end

        if user_role.nil?
          result.status = false
          result['messages'].push('Invalid user Role')
        else
          # Make sure we have at least one super admin
          if current_user.can?('make_super_admin') && !params[:role]['make_super_admin'] &&
            User.includes(:role).where('roles.make_super_admin = 1').length < 2 && !@user.role.nil? && @user.role.make_super_admin
            result['status'] = false
            result['messages'].push('The app needs at least one super admin at all times')
          elsif !current_user.can?('make_super_admin') &&
            ((params[:role]['make_super_admin'] && (@user.role.nil? || !@user.role.make_super_admin)) ||
              (!params[:role]['make_super_admin'] && !@user.role.nil? && @user.role.make_super_admin))
            result['status'] = false
            result['messages'].push('You can not grant or revoke super admin privileges.')
          else
            if user_role.custom && !user_role.display
              user_role = update_role(user_role, params[:role])
            end

            @user.role = user_role
          end
        end


        if @user.save
          result['user'] = @user.attributes
          result['user']['role'] = @user.role.attributes
          result['user']['current_user'] = current_user
          # send user data to groovelytics server if the user is newly created.
          if new_user && !Rails.env.test?
            tenant_name = Apartment::Tenant.current
            send_user_info_obj = SendUsersInfo.new()
            # send_user_info_obj.build_send_users_stream(tenant_name)
            send_user_info_obj.delay(:run_at => 1.seconds.from_now, :queue => 'send_users_info_#{tenant_name}').build_send_users_stream(tenant_name)
          else
            HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/users/update_username",
                  query: { username: @user.username, packing_user_id: @user.id, active: @user.active },
                  headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current }) rescue nil if @user.present?
          end

        else
          result['status'] = false
          result['messages'] = @user.errors.full_messages
        end
      end
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to Add or Edit users")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def get_roles
    result = {}
    result['status'] = true
    result['messages'] = []
    result['roles'] = Role.where(:display => true)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def print_confirmation_code
    user = User.find(params[:id])
    @action_code = user.confirmation_code

    respond_to do |format|
      format.html
      format.pdf {
        render :pdf => 'confirmation_code_'+user.username.to_s,
               :template => 'settings/action_barcodes.html.erb',
               :orientation => 'Portrait',
               :page_height => '1in',
               :page_width => '3in',
               :margin => {
                 :top => '0',
                 :bottom => '0',
                 :left => '0',
                 :right => '0'
               }
      }
    end
  end

  def create_role
    result = {}
    result['status'] = true
    result['messages'] = []

    if current_user.can? 'add_edit_users'
      if params[:role].nil?
        result['status'] = false
        result['messages'].push("No role data sent")
      elsif params[:role]['new_name'].blank? || params[:role]['new_name'][0, 5] == "role_" || !Role.find_by_name(params[:role]['new_name']).nil?
        result['status'] = false
        result['messages'].push("Role name invalid. Please input a valid Role name")
      else
        if params[:role]['id'].nil?
          user_role = Role.find_by_name("role_#{params[:id]}")
          if user_role.nil?
            user_role = Role.new
          end
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
          result['messages'].push("Role saved but could not apply to user. Please click save and close to apply manually")
        else
          user.role = user_role
          user.save
        end
      end
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to create roles")
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update_user_status
    if current_user.can? 'add_edit_users'
      user = User.find(params["id"])
      params["active"] == "active" ? user.active = true : user.active = false
      user.save
      HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/users/update_username",
                  query: { username: user.username, packing_user_id: user.id, active: user.active },
                  headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current }) rescue nil if user.present?
    end
    render json: {status: true}
  end

  def delete_role
    result = {}
    result['status'] = true
    result['messages'] = []

    if current_user.can? 'add_edit_users'
      if params[:role].nil? || params[:role]['id'].nil?
        result['status'] = false
        result['messages'].push("No role data sent")
      else
        if params[:role]['id'].nil?
          user_role = Role.find_by_name("role_#{@user.id}")
          if user_role.nil?
            user_role = Role.new
          end
        else
          user_role = Role.find_by_id(params[:role]['id'])
        end

        scan_pack_role = Role.find_by_name("Scan & Pack User")
        User.where(:role_id => user_role.id).update_all(:role_id => scan_pack_role.id)
        user_role.destroy

        result['role'] = scan_pack_role
      end
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to delete roles")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def change_user_status
    result = {}
    result['status'] = true
    result['messages'] = []

    if current_user.can? 'add_edit_users'
      params['_json'].each do |user|
        @user = User.find(user["id"])
        @user.active = user["active"]
        if !@user.save
          result['status'] = false
        end
      end
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to update user status")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def edituser
  end

  def duplicate_user
    result = {}
    result['status'] = true
    if current_user.can? 'add_edit_users'
      params['_json'].each do |user|
        if User.can_create_new?
          @user = User.find(user["id"])
          #@newuser = User.new
          @newuser = @user.dup
          index = 0
          @newuser.username = @user.username+"(duplicate"+index.to_s+")"
          @userslist = User.where(:username => @newuser.username)
          begin
            index = index + 1
            @newuser.username = @user.username+"(duplicate"+index.to_s+")"
            @userslist = User.where(:username => @newuser.username)
          end while (!@userslist.nil? && @userslist.length > 0)

          @newuser.password = @user.password
          @newuser.password_confirmation = @user.password_confirmation
          @newuser.confirmation_code = @user.confirmation_code+'1'
          @newuser.last_sign_in_at = '' 
          if !@newuser.save(:validate => false)
            result['status'] = false
            result['messages'] = @newuser.errors.full_messages
          end
          tenant_name = Apartment::Tenant.current
          send_user_info_obj = SendUsersInfo.new()
          send_user_info_obj.delay(:run_at => 1.seconds.from_now, :queue => 'send_users_info_#{tenant_name}').build_send_users_stream(tenant_name)
        else
          result['status'] = false
          result['messages'] = "You have reached the maximum limit of number of users for your subscription."
        end
      end
    else
      result['status'] = true
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def delete_user
    result = {}
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'add_edit_users'
      params['_json'].each do |user|
        unless user['id'] == current_user.id
          @user = User.find(user['id'])
          @user.username += '-' + Random.rand(10000000..99999999).to_s
          @user.is_deleted = true
          @user.active = false
          @user.save
          HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/users/delete_user",
                  query: { username: @user.username, packing_user_id: @user.id },
                  headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current }) rescue nil if @user.present?
        end
      end
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to delete users")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def show
    @user = User.find(params[:id])
    result = {}

    if !@user.nil?
      result['status'] = true
      result['user'] = @user
      result['user']['role'] = @user.role
      result['user']['current_user'] = current_user
    else
      result['status'] = false
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def create_tenant
    result = {}
    result['messages'] = []
    tenant = Tenant.new
    tenant.name = params[:name]

    if tenant.save
      Apartment::Tenant.create(tenant.name)
      Apartment::Tenant.switch(tenant.name)
      seed_obj = Groovepacker::SeedTenant.new
      seed_obj.seed
      result['messages'] = 'Tenant successfully created'
      Apartment::Tenant.switch()
    else
      result['messages'] = tenant.errors.full_messages
    end
    respond_to do |format|
      format.json { render json: result }
    end
  end

  def let_user_be_created
    render json: {
             can_create: User.can_create_new?
           }
  end

  def get_user_email
    result = {}
    user = User.find_by_username(params["user"])
    if user == nil
      result[:msg] = "Not a Valid User"
      result[:code] = 0
    else
      email = user.send_reset_password_instructions
      user.reset_token = email
      user.save!
      result[:msg] = "A password reset link has been emailed to the address associated with your user account: #{user.email}"
      result[:code] = 1
    end
      render json: result
  end

  def update_password
    result = {}
    user = User.find(params["user_id"])
    if user.reset_token == params["reset_password_token"]
      user.password = params["password"]
      user.password_confirmation = params["password_confirmation"]
      user.reset_token = nil
      user.save
      result[:msg] = "Updated successfully"
      result[:code] = 1
    else
      result[:msg] = "Token is expired"
      result[:code] = 0
    end
    render json: result
  end
end
