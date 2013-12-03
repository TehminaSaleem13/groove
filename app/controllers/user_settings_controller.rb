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
    @user.password = params[:password]
    @user.username = params[:username]
    @user.password_confirmation = params[:password]
    if params[:active].nil?
      params[:active] = false
    end
    @user.active = params[:active]
    @user.name = params[:name]

    #add product details
    @user.edit_product_details = params[:edit_product_details]
    @user.add_products = params[:add_products]
    @user.edit_products = params[:edit_products]
    @user.delete_products = params[:delete_products]
    @user.other = params[:other1]
    @user.import_products = params[:import_products]
    @user.edit_product_import = params[:edit_product_import]

    #add order details
    @user.import_orders = params[:import_orders]
    @user.change_order_status = params[:change_order_status]
    @user.createEdit_from_packer = params[:createEdit_packer]
    @user.add_order_items_ALL = params[:add_order_items_ALL]
    @user.add_order_items = params[:add_order_items]
    @user.remove_order_items = params[:remove_order_items]
    @user.change_quantity_items = params[:change_quantity_items]
    @user.view_packing_ex = params[:view_packing_ex]
    @user.create_packing_ex = params[:create_packing_ex]
    @user.edit_packing_ex = params[:edit_packing_ex]
    @user.order_edit_confirmation_code = params[:order_edit_confirmation_code]

    #add user details permissions
    @user.edit_user_info = params[:edit_user_info]
    @user.edit_user_status = params[:edit_user_status]
    @user.is_super_admin = params[:is_super_admin]
    @user.create_users = params[:create_users]
    @user.edit_user_permissions = params[:edit_user_permissions]
    @user.access_scanpack = params[:access_scanpack]
    @user.access_orders = params[:access_orders]
    @user.access_products = params[:access_products]


    #add system settings permission
    @user.edit_general_prefs = params[:edit_general_prefs]
    @user.edit_scanning_prefs = params[:edit_scanning_prefs]

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
