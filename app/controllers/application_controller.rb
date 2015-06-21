class ApplicationController < ActionController::Base
  before_filter :set_current_user_id
  protect_from_forgery with: :null_session

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
      cookies['_validation_token_key'] = Digest::MD5.hexdigest("#{current_user.id}:#{session.to_json}:#{Apartment::Tenant.current_tenant}")
      # store session data or any authentication data you want here, generate to JSON data
      stored_session = JSON.generate({'tenant'=>Apartment::Tenant.current_tenant, 'user_id'=> current_user.id, 'username'=>current_user.username})
      $redis.hset('groovehacks:session',cookies['_validation_token_key'],stored_session)
      super(resource_or_scope)
    end

  end

  def after_sign_out_path_for(resource_or_scope)
    #expire session in redis
    if cookies['_validation_token_key'].present?
      $redis.hdel('groovehacks:session', cookies['_validation_token_key'])
    end
    super(resource_or_scope)
  end
end
