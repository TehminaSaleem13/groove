# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_current_user_id
  around_action :set_time_zone
  protect_from_forgery with: :null_session

  respond_to :html, :json

  def groovepacker_authorize!
    auth_header = request.headers['Authorization']
    if !auth_header.nil? && auth_header.include?('Bearer')
      doorkeeper_authorize!
      @current_user = User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
      User.current = @current_user
      check_for_existing_logins(doorkeeper_token)
      stored_session = JSON.generate('tenant' => Apartment::Tenant.current, 'user_id' => @current_user.try(:id), 'username' => @current_user.try(:username))
      $redis.hset('groovehacks:session', auth_header.gsub('Bearer ', ''), stored_session)
    else
      render status: 401, json: 'Unauthorized Access'
    end
  end

  def verify_authenticity_token
    auth_header = request.headers['Authorization']
    return if auth_header&.include?('Bearer') && !current_user.nil?
    raise
  rescue
    super
  end

  def set_current_user_id
    GroovRealtime.current_user_id = current_user ? current_user.id : 0
  end

  def set_time_zone
    Time.use_zone(GeneralSetting.new_time_zone) { yield }
  end

  def after_sign_in_path_for(resource_or_scope)
    # store session to redis
    if current_user
      user = current_user
      user.last_sign_in_at = DateTime.now.in_time_zone
      user.save
      save_bc_auth_if_present
      # an unique MD5 key
      cookies['_validation_token_key'] = Digest::MD5.hexdigest("#{current_user.id}:#{session.to_json}:#{Apartment::Tenant.current}")
      # store session data or any authentication data you want here, generate to JSON data
      stored_session = JSON.generate('tenant' => Apartment::Tenant.current, 'user_id' => current_user.id, 'username' => current_user.username)
      $redis.hset('groovehacks:session', cookies['_validation_token_key'], stored_session)
      if session[:redirect_uri]
        session[:redirect_uri]
      else
        super(resource_or_scope)
      end
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    # expire session in redis
    if cookies['_validation_token_key'].present?
      $redis.hdel('groovehacks:session', cookies['_validation_token_key'])
    end
    session[:redirect_uri] = nil
    super(resource_or_scope)
  end

  def current_time_in_gp(time = Time.current)
    general_setting = GeneralSetting.all.first
    offset = general_setting.try(:time_zone).to_i
    offset = general_setting.try(:dst) ? offset : offset + 3600
    time + offset
  end

  def check_for_dst(offset)
    tz_name = Groovepacks::Application.config.time_zone_names.values.first.key(offset.to_i)
    return false if tz_name.nil? || GeneralSetting.all.first.try(:dst)
    ActiveSupport::TimeZone[tz_name].tzinfo.current_period.dst?
  end

  private

  def save_bc_auth_if_present
    bc_auth = cookies[:bc_auth]
    unless bc_auth.blank?
      access_token = bc_auth['access_token'] rescue nil
      store_hash = bc_auth['context'] rescue nil
      @store = Store.new
      @store = @store.create_store_with_defaults('BigCommerce')
      BigCommerceCredential.create(store_id: @store.id, access_token: access_token, store_hash: store_hash)
      # cookies.delete(:bc_auth)
      cookies[:bc_auth] = { value: nil, domain: :all, expires: Time.current + 2.seconds }
    end
  end

  def check_for_existing_logins(doorkeeper_token)
    return unless doorkeeper_token
    # Check if request is from Expo React Native App
    return if request.headers['HTTP_EXAPP'].blank? || @current_user.username == 'gpadmin'

    GroovRealtime.emit('force_logout', { username: @current_user.username }, :tenant)
    @current_user.doorkeeper_tokens.where.not(id: doorkeeper_token.id).delete_all
  end

  def get_host_url
    url = ''
    current_tenant = Apartment::Tenant.current
    url = if Rails.env == 'producttion'
            "https://#{current_tenant}.groovepacker.com"
          elsif Rails.env == 'staging'
            "https://#{current_tenant}.barcodepacker.com"
          else
            "https://#{request.host}"
          end
    url
  end
end
