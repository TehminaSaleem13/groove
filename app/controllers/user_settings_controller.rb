class UserSettingsController < ApplicationController
  include UserSettingsHelper

  def userslist
    @users = User.all

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @users, :only => [:id, :username, :last_sign_in_at, :active], :include => :role}
    end
  end

  def createUser

      puts "user:" + user.inspect
      @result = Hash.new
      @result['status'] = true
      @result['messages'] = []
    if can_user_be_created
      if current_user.can? 'add_edit_users'
        if !params[:id].nil?
          @user = User.find(params[:id])
        else
          @user = User.new
        end

        @user.email = params[:email]
        @user.password = params[:password] if !params[:password].nil? && params[:password] != ''
        @user.username = params[:username]
        @user.other = params[:other] if !params[:other].nil?
        @user.password_confirmation = params[:password] if !params[:password].nil? && params[:password] != ''
        if params[:active].nil?
          params[:active] = false
        end
        @user.active = params[:active]
        @user.name = params[:name]
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
          @result.status = false
          @result['messages'].push("Invalid user Role")
        else

          if params[:role]['make_super_admin'] && !current_user.can?('make_super_admin')
            params[:role]['make_super_admin'] = false
            @result['status'] = false
            @result['messages'].push("Cannot grant super admin privileges to non super admin.")
          end

          if user_role.custom && !user_role.display
            user_role = update_role(user_role,params[:role])
          end

          @user.role = user_role
        end


        if @user.save
          @result['user'] = @user
          @result['user']['role'] = @user.role
        else
          @result['status'] = false
          @result['messages'] = @user.errors.full_messages
          end
      else
        @result['status'] = false
        @result['messages'].push("Current user doesn't have permission to Add or Edit users")
      end

      respond_to do |format|
          format.html # show.html.erb
          format.json { render json: @result}
      end
    else
      render json:{valid: false}
    end
  end

  def getRoles
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    @result['roles'] = Role.where(:display=>true);

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def createRole
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can? 'add_edit_users'
      if params[:role].nil?
        @result['status'] = false
        @result['messages'].push("No role data sent")
      elsif params[:role]['new_name'].blank? || params[:role]['new_name'][0,5] == "role_" || !Role.find_by_name(params[:role]['new_name']).nil?
        @result['status'] = false
        @result['messages'].push("Role name invalid. Please input a valid Role name")
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
        user_role = update_role(user_role,params[:role])
        @result['role'] = user_role
        user = User.find(params[:id])
        if user.nil?
          @result['status'] = false
          @result['messages'].push("Role saved but could not apply to user. Please click save and close to apply manually")
        else
          user.role = user_role
          user.save
        end
      end
    else
      @result['status'] = false
      @result['messages'].push("Current user doesn't have permission to create roles")
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def deleteRole
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can? 'add_edit_users'
      if params[:role].nil? || params[:role]['id'].nil?
        @result['status'] = false
        @result['messages'].push("No role data sent")
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
        User.where(:role_id => user_role.id).update_all(:role_id=> scan_pack_role.id)
        user_role.destroy

        @result['role'] = scan_pack_role
      end
    else
      @result['status'] = false
      @result['messages'].push("Current user doesn't have permission to delete roles")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def changeuserstatus
    @result = Hash.new
    @result['status'] = true
    if current_user.can? 'add_edit_user'
      params['_json'].each do|user|
        @user = User.find(user["id"])
        @user.active = user["active"]
        if !@user.save
          @result['status'] = false
        end
      end
    else
      @result['status'] = false
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def edituser
  end

  def duplicateuser

    @result = Hash.new
    @result['status'] = true
    if current_user.can? 'add_edit_user'
      params['_json'].each do|user|
        @user = User.find(user["id"])
        #@newuser = User.new
        @newuser = @user.dup
        index = 0
        @newuser.username = @user.username+"(duplicate"+index.to_s+")"
        @userslist = User.where(:username=>@newuser.username)
        begin
          index = index + 1
          @newuser.username = @user.username+"(duplicate"+index.to_s+")"
          @userslist = User.where(:username=>@newuser.username)
        end while(!@userslist.nil? && @userslist.length > 0)

        @newuser.password = @user.password
        @newuser.password_confirmation = @user.password_confirmation
        @newuser.last_sign_in_at = ''

        if !@newuser.save(:validate => false)
          @result['status'] = false
          @result['messages'] = @newuser.errors.full_messages
        end
      end
    else
      @result['status'] = true
    end


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deleteuser
    @result = Hash.new
    @result['status'] = true
    if current_user.can? 'add_edit_user'
      params['_json'].each do|user|
        @user = User.find(user["id"])
        if !@user.destroy
          @result['status'] = false
        end
      end
    else
      @result['status'] = false
      @result['messages'].push("Current user doesn't have permission to create roles")
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def getuserinfo
    @user = User.find(params[:id])
    @result = Hash.new

    if !@user.nil?
      @result['status'] = true
      @result['user'] = @user
      @result['user']['role'] = @user.role
    else
      @result['status'] = false
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def create_tenant
    @result = Hash.new
    @result['messages'] = []
    tenant = Tenant.new
    tenant.name = params[:name]

    if tenant.save
      Apartment::Tenant.create(tenant.name)
      Apartment::Tenant.switch(tenant.name)
      seed_obj = SeedTenant.new
      seed_obj.seed
      @result['messages'] = 'Tenant successfully created'
      Apartment::Tenant.switch()
    else
      @result['messages'] = tenant.errors.full_messages
    end
    respond_to do |format|
      format.json {render json: @result}
    end
  end

  private

  def can_user_be_created
    users = User.all
    user_count = users.count
    max_users = AccessRestriction.first.num_users
    user_count < max_users
  end
end
