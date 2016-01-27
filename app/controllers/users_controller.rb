class UsersController < ApplicationController
  before_filter :groovepacker_authorize!
  include UsersHelper

  def index
    @users = User.where('username != ?', 'gpadmin')

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
      if params[:id].nil?
        if User.can_create_new?
          @user = User.new
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
          if !@user.destroy
            result['status'] = false
          end
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
end
