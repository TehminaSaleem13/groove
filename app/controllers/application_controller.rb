# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Encryptable

  before_action :set_current_user_id, :check_request_from_gpx
  before_action :log_request

  around_action :set_time_zone_and_process_request

  protect_from_forgery with: :null_session

  respond_to :html, :json

  def groovepacker_authorize!
    auth_header = request.headers['Authorization']
    if !auth_header.nil? && auth_header.include?('Bearer')
      doorkeeper_authorize!
      @current_user = User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
      User.current = @current_user
      check_for_existing_logins(doorkeeper_token)
      stored_session = JSON.generate('tenant' => Apartment::Tenant.current, 'user_id' => @current_user.try(:id),
                                     'username' => @current_user.try(:username))
      $redis.hset('groovehacks:session', auth_header.gsub('Bearer ', ''), stored_session)
    else
      render status: :unauthorized, json: 'Unauthorized Access'
    end
  end

  def verify_authenticity_token
    auth_header = request.headers['Authorization']
    return if auth_header&.include?('Bearer') && !current_user.nil?

    raise
  rescue StandardError
    super
  end

  def set_current_user_id
    GroovRealtime.current_user_id = current_user ? current_user.id : 0
  end

  def set_time_zone_and_process_request(&block)
    Time.use_zone(GeneralSetting.new_time_zone, &block)
  ensure
    if @incoming_log_request
      duration = Time.current - @incoming_log_request.created_at
      @incoming_log_request.update_columns(duration:, completed: true)
    end
  end

  def after_sign_in_path_for(resource_or_scope)
    # store session to redis
    return unless current_user

    user = current_user
    user.last_sign_in_at = DateTime.now.in_time_zone
    user.save
    save_bc_auth_if_present
    # an unique MD5 key
    cookies['_validation_token_key'] =
      Digest::MD5.hexdigest("#{current_user.id}:#{session.to_json}:#{Apartment::Tenant.current}")
    # store session data or any authentication data you want here, generate to JSON data
    stored_session = JSON.generate('tenant' => Apartment::Tenant.current, 'user_id' => current_user.id,
                                   'username' => current_user.username)
    $redis.hset('groovehacks:session', cookies['_validation_token_key'], stored_session)
    session[:redirect_uri] || super(resource_or_scope)
  end

  def after_sign_out_path_for(resource_or_scope)
    # expire session in redis
    $redis.hdel('groovehacks:session', cookies['_validation_token_key']) if cookies['_validation_token_key'].present?
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

  def check_request_from_gpx
    return if request.headers['HTTP_ON_GPX'].blank?

    params['data'].each do |item|
      item.merge!({ on_ex: request.headers['HTTP_ON_GPX'] })
    end
  rescue StandardError
  end

  def save_bc_auth_if_present
    bc_auth = cookies[:bc_auth]
    return if bc_auth.blank?

    access_token = begin
      bc_auth['access_token']
    rescue StandardError
      nil
    end
    store_hash = begin
      bc_auth['context']
    rescue StandardError
      nil
    end
    @store = Store.new
    @store = @store.create_store_with_defaults('BigCommerce')
    BigCommerceCredential.create(store_id: @store.id, access_token:, store_hash:)
    # cookies.delete(:bc_auth)
    cookies[:bc_auth] = { value: nil, domain: :all, expires: Time.current + 2.seconds }
  end

  def check_for_existing_logins(doorkeeper_token)
    return unless doorkeeper_token
    # Check if request is from Expo React Native App
    return if request.headers['HTTP_EXAPP'].blank? || @current_user.username == 'gpadmin'

    GroovRealtime.emit('force_logout', { username: @current_user.username }, :tenant)
    @current_user.doorkeeper_tokens.where.not(id: doorkeeper_token.id).delete_all
  end

  def get_host_url
    current_tenant = Apartment::Tenant.current
    if Rails.env.production?
      "https://#{current_tenant}.groovepacker.com"
    elsif Rails.env.staging?
      "https://#{current_tenant}.barcodepacker.com"
    else
      "https://#{request.host}"
    end
  end

  def log_request
    @incoming_log_request = RequestLog.create(
      request_method: request.method,
      request_path: request.path,
      request_body: compress_and_encrypt(params.to_json)
    )
  rescue StandardError
    Groovepacker::LogglyLogger.log(Apartment::Tenant.current, 'log-request-failures',
                                   { request_method: request.method, request_path: request.path, params: })
  end
end
