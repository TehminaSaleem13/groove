# frozen_string_literal: true

class HomeController < ApplicationController
  layout 'angular'

  before_action :groovepacker_authorize!, except: [:check_tenant]

  def index
    # if current user is not signed in, show login page
    if !user_signed_in?
      redirect_to new_user_session_path
    else
      @groovepacks_admin = (Apartment::Tenant.current == 'admintools') || (Apartment::Tenant.current == 'scadmintools')
    end
    @current_tenant = Apartment::Tenant.current
  end

  def userinfo
    user = {}
    unless current_user.nil?
      user['username'] = current_user.username
      user['name'] = current_user.name
      user['view_dashboard'] = current_user.view_dashboard
      user['id'] = current_user.id
      user['role'] = current_user.role
      user['current_tenant'] = Apartment::Tenant.current
      user['is_active'] = current_user.active
      user['dashboard_switch'] = current_user.dashboard_switch
      user['confirmation_code'] = current_user.confirmation_code
      scan_pack_setting = ScanPackSetting.last
      if scan_pack_setting.require_serial_lot && scan_pack_setting.valid_prefixes.present?
        user['all_users_confirmation_code'] = User.pluck(:confirmation_code)
        barcode_prefix = scan_pack_setting.valid_prefixes.split(',').reject(&:empty?).map(&:strip)
        query_conditions = barcode_prefix.map { |prefix| "barcode LIKE ?" }.join(" OR ")
        placeholders = barcode_prefix.map { |prefix| "#{prefix}%" }
        user['all_barcodes'] = ProductBarcode.where(query_conditions, *placeholders).pluck(:barcode)
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: user }
    end
  end

  def request_socket_notifs
    GenerateBarcode.where("status != 'completed' AND status != 'failed' AND status != 'cancelled'").each(&:emit_data_to_user)
    CsvProductImport.where("status != 'completed' AND status != 'cancelled'").each(&:emit_data_to_user)
    import_summary = OrderImportSummary.top_summary
    import_summary&.emit_data_to_user(true)
    render json: { status: true }
  end

  def import_status
    render json: { status: true, summary: OrderImportSummary.top_summary&.import_data(true) }
  end

  def check_tenant
    result = true
    tenant = params['tenant']
    begin
      Apartment::Tenant.switch! tenant
      result = true
    rescue StandardError
      result = false
    end
    render json: { status: result }
  end
end
