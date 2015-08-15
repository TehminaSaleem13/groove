class ApplicationController < ActionController::Base
  before_filter :set_current_user_id
  protect_from_forgery with: :null_session

  respond_to :html, :json

  def groovepacker_authorize!
    auth_header = request.headers["Authorization"]
    if auth_header.nil?
      authenticate_user!
    elsif auth_header.include?("Bearer")
      doorkeeper_authorize!
      @current_user = User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
    else
      render status: 401
    end
  end

  def set_current_user_id
    if current_user
      GroovRealtime.current_user_id = current_user.id
    else
      GroovRealtime.current_user_id = 0
    end
  end

  def after_sign_in_path_for(resource_or_scope)
    #store session to redis
    if current_user
      # an unique MD5 key
      cookies['_validation_token_key'] = Digest::MD5.hexdigest("#{current_user.id}:#{session.to_json}:#{Apartment::Tenant.current}")
      # store session data or any authentication data you want here, generate to JSON data
      stored_session = JSON.generate({'tenant' => Apartment::Tenant.current, 'user_id' => current_user.id, 'username' => current_user.username})
      $redis.hset('groovehacks:session', cookies['_validation_token_key'], stored_session)
      if session[:redirect_uri]
        session[:redirect_uri]
      else
        super(resource_or_scope)
      end
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    #expire session in redis
    if cookies['_validation_token_key'].present?
      $redis.hdel('groovehacks:session', cookies['_validation_token_key'])
    end
    session[:redirect_uri] = nil
    super(resource_or_scope)
  end

end
