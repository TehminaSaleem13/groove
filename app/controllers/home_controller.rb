class HomeController < ApplicationController
  def index
  	#if current user is not signed in, show login page
  	if !user_signed_in?
  		redirect_to new_user_session_path
  	end

  end

  def userinfo
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: current_user}
    end
  end
end
