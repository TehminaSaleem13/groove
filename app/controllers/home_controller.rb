class HomeController < ApplicationController
  def index
  	#if current user is not signed in, show login page
  	if !user_signed_in?
  		redirect_to new_user_session_path
  	end
  	
  end

  def userinfo
  	@user = Hash.new
  	@user['username'] = current_user.username
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user}
    end
  end
end
