class UserSettingsController < ApplicationController
  def userslist
    @users = User.all

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @users, :only => [:id, :username, :last_sign_in_at, :is_super_admin, :active]}
    end
  end

  def createUser
    @result = Hash.new
    if !params[:id].nil?
      @user = User.find(params[:id])
    else
      @user = User.new
    end

    @user.email = params[:email]
    @user.password = params[:password] if !params[:password].nil? && params[:password] != ''
    @user.username = params[:username]
    @user.password_confirmation = params[:password] if !params[:password].nil? && params[:password] != ''
    if params[:active].nil?
      params[:active] = false
    end
    @user.active = params[:active]
    @user.name = params[:name] 
    @user.confirmation_code = params[:confirmation_code]

    #add product details
    @user.edit_product_details = params[:edit_product_details] if !params[:edit_product_details].nil?
    @user.add_products = params[:add_products] if !params[:add_products].nil?
    @user.edit_products = params[:edit_products] if !params[:edit_products].nil?
    @user.delete_products = params[:delete_products] if !params[:delete_products].nil?
    @user.other = params[:other1] if !params[:other1].nil?
    @user.import_products = params[:import_products] if !params[:import_products].nil?
    @user.edit_product_import = params[:edit_product_import] if !params[:edit_product_import].nil?

    #add order details
    @user.import_orders = params[:import_orders] if !params[:import_orders].nil?
    @user.change_order_status = params[:change_order_status] if !params[:change_order_status].nil?
    @user.createEdit_from_packer = params[:createEdit_packer] if !params[:createEdit_packer].nil?
    @user.add_order_items_ALL = params[:add_order_items_ALL] if !params[:add_order_items_ALL].nil?
    @user.add_order_items = params[:add_order_items] if !params[:add_order_items].nil?
    @user.remove_order_items = params[:remove_order_items] if !params[:remove_order_items].nil?
    @user.change_quantity_items = params[:change_quantity_items] if !params[:change_quantity_items].nil?
    @user.view_packing_ex = params[:view_packing_ex] if !params[:view_packing_ex].nil?
    @user.create_packing_ex = params[:create_packing_ex] if !params[:create_packing_ex].nil?
    @user.edit_packing_ex = params[:edit_packing_ex] if !params[:edit_packing_ex].nil?

    #add user details permissions
    @user.edit_user_info = params[:edit_user_info] if !params[:edit_user_info].nil?
    @user.edit_user_status = params[:edit_user_status] if !params[:edit_user_status].nil?
    @user.is_super_admin = params[:is_super_admin] if !params[:is_super_admin].nil?
    @user.create_users = params[:create_users] if !params[:create_users].nil?
    @user.edit_user_permissions = params[:edit_user_permissions] if !params[:edit_user_permissions].nil?
    @user.access_scanpack = params[:access_scanpack] if !params[:access_scanpack].nil?
    @user.access_orders = params[:access_orders] if !params[:access_orders].nil?
    @user.access_products = params[:access_products] if !params[:access_products].nil?

    #add system settings permission
    @user.edit_general_prefs = params[:edit_general_prefs] if !params[:edit_general_prefs].nil?
    @user.edit_scanning_prefs = params[:edit_scanning_prefs] if !params[:edit_scanning_prefs].nil?

    if @user.save
      @result['result'] = true
    else
      @result['result'] = false
      @result['messages'] = @user.errors.full_messages 
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result}
    end
  end

  def changeuserstatus
    @result = Hash.new
    @result['status'] = true
    params['_json'].each do|user|
      @user = User.find(user["id"])
      @user.active = user["active"]
      if !@user.save
        @result['status'] = false
      end
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


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deleteuser
    @result = Hash.new
    @result['status'] = true
    params['_json'].each do|user|
      @user = User.find(user["id"])
      if !@user.destroy
        @result['status'] = false
      end
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
    else
      @result['status'] = false
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end
end
