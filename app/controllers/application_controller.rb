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
      user = current_user
      user.last_sign_in_at=DateTime.now
      user.save
      save_bc_auth_if_present
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
  
  private
    def save_bc_auth_if_present
      bc_auth = cookies[:bc_auth]
      unless bc_auth.blank?
        access_token = bc_auth["access_token"] rescue nil
        store_hash = bc_auth["context"] rescue nil
        @store = Store.new
        @store = @store.create_store_with_defaults("BigCommerce")
        BigCommerceCredential.create(store_id: @store.id, access_token: access_token, store_hash: store_hash )
        #cookies.delete(:bc_auth)
        cookies[:bc_auth] = {:value => nil , :domain => :all, :expires => Time.now+2.seconds}
      end
    end

    def get_host_url
      url = ""
      current_tenant = Apartment::Tenant.current
      if Rails.env=="producttion"
        url = "https://#{current_tenant}.groovepacker.com"
      elsif Rails.env=="staging"
        url = "https://#{current_tenant}.barcodepacker.com"
      else
        url = "https://#{request.host}"
      end
      return url
    end

end
