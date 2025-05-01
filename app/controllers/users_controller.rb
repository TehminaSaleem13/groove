# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :groovepacker_authorize!, except: %i[get_user_email update_password]
  include UsersHelper

  def index
    @users = User.includes(%i[role last_order_activity last_product_activity]).where(
      'username != ? and is_deleted = ?', 'gpadmin', false
    )
  
    max_administrative_users = AccessRestriction.last&.administrative_users || 0
  
    current_administrative_users = @users.count { |user| user.role && user.role['name'].include?('Administrative') }
  
    render json: @users.as_json(
      only: %i[id username active], 
      include: { role: { only: %i[id name] } }, 
      methods: %i[last_activity role]
    ).map { |user| user.merge(
      max_administrative_users: max_administrative_users,
      current_administrative_users: current_administrative_users
    )}
  end
  

  def modify_plan
    result = {}
    result['status'] = true
    tenant = Tenant.find_by_name(Apartment::Tenant.current)
    @subscription = tenant.subscription
    if @subscription.customer_subscription_id.present? && @subscription.stripe_customer_id.present?
      access_restriction = AccessRestriction.last
      data = { users: params[:users], amount: params[:amount], is_annual: params[:is_annual] }
      result['request_send'] =
        if tenant.created_at > '2016-09-23 00:00:00'
          remove_user(data, access_restriction,
                      tenant)
        else
          check_for_removal(data, access_restriction,
                            tenant)
        end
      if params[:is_annual] == 'false' && params[:users].to_i > access_restriction.num_users && @subscription['interval'] != 'year'
        ui_user = params[:users].to_i - access_restriction.num_users
        access_restriction.update(added_through_ui: ui_user)
        tenant.activity_log = "#{Time.current.strftime('%Y-%m-%d  %H:%M')} User added: From #{access_restriction.num_users} user plan to #{params[:users]} user and amount is #{params[:amount]}\n" + tenant.activity_log.to_s
        tenant.save!
        StripeInvoiceEmail.add_user_notification(tenant, params[:users].to_i, access_restriction).deliver
        access_restriction.update(num_users: params[:users])
        set_subscription_info(params[:amount])
        create_stripe_plan(tenant)
      elsif params[:is_annual] == 'true'
        StripeInvoiceEmail.annual_plan(tenant, params[:users].to_i, params[:amount]).deliver
        result['annual_request'] = true
      elsif @subscription['interval'] == 'year' && params[:is_annual] == 'false' && params[:users].to_i != access_restriction.num_users
        result['status'] = false
        result['error_messages'] = "Can't Change Yearly Plan to Monthly"
      end
    else
      result['status'] = false
      result['error_messages'] = 'Please contact GroovePacker support to add additional users'
    end

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def createUpdateUser
    result = {}
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'add_edit_users'
      @new_user = false
      retrieve_or_create_new_user(params)
      check_for_invalid_password(params, result)
      save_or_update_user(result, params)
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to Add or Edit users")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def get_roles
    result = {}
    result['status'] = true
    result['messages'] = []
    result['roles'] = Role.where(display: true)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def print_confirmation_code
    require 'wicked_pdf'
    user = User.find(params[:id])
    @action_code = user.confirmation_code
    tenant_name = Apartment::Tenant.current
    file_name = 'confirmation_code_' + user.username.to_s
    packing_slip_obj = Groovepacker::PackingSlip::PdfMerger.new
    action_view = packing_slip_obj.do_get_action_view_object_for_html_rendering
    pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}.pdf")
    pdf_html = action_view.render template: 'settings/action_barcodes.html.erb', layout: nil,
                                  locals: { :@action_code => @action_code }
    doc_pdf = WickedPdf.new.pdf_from_string(
      pdf_html, inline: true, save_only: false,
                orientation: 'Portrait', page_height: '1in', page_width: '3in',
                margin: { top: '0', bottom: '0', left: '0', right: '0' }
    )
    File.open(pdf_path, 'wb') do |file|
      file << doc_pdf
    end
    base_file_name = File.basename(pdf_path)
    pdf_file = File.open(pdf_path)
    GroovS3.create_pdf(tenant_name, base_file_name, pdf_file.read)
    pdf_file.close
    generate_barcode = ENV['S3_BASE_URL'] + '/' + tenant_name + '/pdf/' + base_file_name
    render json: { url: generate_barcode }
  end

  def create_role
    result = {}
    result['status'] = true
    result['messages'] = []

    if current_user.can? 'add_edit_users'
      create_existing_role(params, result)
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to create roles")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end  

  def update_user_status
    if current_user.can? 'add_edit_users'
      user = User.find(params['id'])
      # params["active"] == "active" ? user.active = true : user.active = false
      user.active = params['active'] == 'active'
      user.save
      begin
        HTTParty.post("#{ENV['GROOV_ANALYTIC_URL']}/users/update_username",
                      query: { username: user.username, packing_user_id: user.id, active: user.active,
                               time_zone: GeneralSetting.last&.new_time_zone },
                      headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current })
      rescue StandardError
        nil
      end
    end
    render json: { status: true }
  end

  def delete_role
    result = {}
    result['status'] = true
    result['messages'] = []

    if current_user.can? 'add_edit_users'
      delete_existing_role(params, result)
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to delete roles")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def change_user_status
    result = {}
    result['status'] = true
    result['messages'] = []

    if current_user.can? 'add_edit_users'
      params['_json'].each do |user|
        @user = User.find(user['id'])
        @user.active = user['active']
        result['status'] = false unless @user.save
      end
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to update user status")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def edituser; end

  def duplicate_user
    result = {}
    result['status'] = true
    if current_user.can? 'add_edit_users'
      params['_json'].each do |user|
        check_and_create_duplicate_user(user, result)
      end
    else
      result['status'] = true
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def delete_user
    result = {}
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'add_edit_users'
      users = []
      user_names = []
      delete_existing_user(result, users, user_names)
      StripeInvoiceEmail.user_delete_request_email(users, user_names).deliver if users.any?
    else
      result['status'] = false
      result['messages'].push("Current user doesn't have permission to delete users")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def show
    @user = if params[:confirmation_code].present?
              User.find_by_confirmation_code(params[:confirmation_code])
            else
              User.find(params[:id])
            end
    result = {}

    if !@user.nil?
      result['status'] = true
      result['user'] = @user
      result['user'] = result['user'].attributes.merge('role' => @user.role, 'current_user' => current_user)
    else
      result['status'] = false
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def create_tenant
    result = {}
    result['messages'] = []
    tenant = Tenant.new
    tenant.name = params[:name]

    if tenant.save
      Apartment::Tenant.create(tenant.name)
      Apartment::Tenant.switch!(tenant.name)
      seed_obj = Groovepacker::SeedTenant.new
      seed_obj.seed
      result['messages'] = 'Tenant successfully created'
      Apartment::Tenant.switch!
    else
      result['messages'] = tenant.errors.full_messages
    end
    respond_to do |format|
      format.json { render json: result }
    end
  end

  def let_user_be_created
    render json: {
      can_create: User.can_create_new?
    }
  end

  def get_user_email
    result = {}
    user = User.find_by(username: params['user'])
    result[:code] = 0
    admin_email = (Role.find_by(name: 'Super Admin').try(:users) || []).pluck(:email).compact.first
    if user.nil?
      result[:msg] = 'Unable to login. Please check your username'
    elsif (user.email.blank? || user.email.split('@')[1].blank?) && admin_email.blank?
      result[:msg] =
        'Unfortunately you do not have a password recovery email address. Please contact a team leader who can reset your password.'
    else
      send_email_reset_instruction(user, result, admin_email)
    end
    render json: result
  end

  def update_email
    user = User.find_by(username: params['username'])
    user.email = params['email']
    user.save
    render json: {}
  end

  def get_email
    user = User.find_by(username: params['username'])
    status = user.try(:role_id).in? [1, 2]
    render json: { email: user.try(:email), status: }
  end

  def update_password
    result = {}
    user = User.find(params['user_id'])
    if user.reset_token == params['reset_password_token']
      user.password = params['password']
      user.password_confirmation = params['password_confirmation']
      user.reset_token = nil
      user.save
      result[:msg] = 'Updated successfully'
      result[:code] = 1
    else
      result[:msg] = 'Token is expired'
      result[:code] = 0
    end
    render json: result
  end

  def update_login_date
    user = User.find_by(username: params['username'])
    if user.present?
      user.current_sign_in_at = DateTime.now.in_time_zone
      user.last_sign_in_at = DateTime.now.in_time_zone
      user.last_login_time = DateTime.now.in_time_zone
      user.save
      begin
        HTTParty.post("#{ENV['GROOV_ANALYTIC_URL']}/users/update_login",
                      query: {packing_user_id: user.id, active: user.active,  current_sign_in_at: user.last_login_time, last_sign_in_at: user.last_logout_time, sign_in_count: user.total_login_time,
                               time_zone: GeneralSetting.last&.new_time_zone },
                      headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current })
      rescue StandardError
        nil
      end
    end
    render json: {}
  end

  def update_logout_time
    if current_user.present?
      current_user.update(last_logout_time: params[:logout_time])
      current_user.save
      begin
        HTTParty.post("#{ENV['GROOV_ANALYTIC_URL']}/users/update_logout",
          query: {packing_user_id: current_user.id, active: current_user.active, last_sign_in_at: current_user.last_logout_time, sign_in_count: current_user.total_login_time,
                   time_zone: GeneralSetting.last&.new_time_zone },
          headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current })
      rescue StandardError
        nil
      end
          head :no_content
    else
      render json: { error: 'User not found' }, status: :unauthorized
    end
  end

  def get_super_admin_email
    render json: { email: (Role.find_by(name: 'Super Admin').try(:users) || []).pluck(:email).compact.first }
  end

  def set_custom_fields
    general_setting = GeneralSetting.first
    @custom_field_one_key = general_setting.custom_user_field_one
    @custom_field_one_value = @user.custom_field_one

    @custom_field_two_key = general_setting.custom_user_field_two
    @custom_field_two_value = @user.custom_field_two
  end

  def invoices
    result = {}
    result['status'] = true
    tenant = Tenant.find_by_name(Apartment::Tenant.current)
    subscription = tenant.subscription
    
    if subscription.present?
      begin
        result['invoice_data'] = fetch_invoices(subscription.stripe_customer_id)
      rescue => e
        result['status'] = false
        result['error'] = e.message
      end
    else
      result['status'] = false
      result['error'] = 'Subscription not found'
    end

    render json: result
  end
end
