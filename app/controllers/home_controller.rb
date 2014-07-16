class HomeController < ApplicationController
  def index
  	#if current user is not signed in, show login page
  	if !user_signed_in?
  		redirect_to new_user_session_path
  	end

  end

  def userinfo
    user =  Hash.new
    user['username'] = current_user.username
    user['name'] = current_user.name
    user['id'] = current_user.id
    user['role'] = current_user.role
    user['current_tenant'] = Apartment::Tenant.current_tenant

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: user}
    end
  end
end
