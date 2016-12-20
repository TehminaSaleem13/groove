class HomeController < ApplicationController
  layout 'angular'

  before_filter :groovepacker_authorize!

  def index
    #if current user is not signed in, show login page
    if !user_signed_in?
      redirect_to new_user_session_path
    else
      @groovepacks_admin = (Apartment::Tenant.current == 'admintools')
    end
    @current_tenant = Apartment::Tenant.current 
  end

  def userinfo
    user = Hash.new
    unless current_user.nil?
      user['username'] = current_user.username
      user['name'] = current_user.name
      user['view_dashboard'] = current_user.view_dashboard
      user['id'] = current_user.id
      user['role'] = current_user.role
      user['current_tenant'] = Apartment::Tenant.current
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: user }
    end
  end

  def request_socket_notifs
    GenerateBarcode.where("status != 'completed' AND status != 'failed' AND status != 'cancelled'").each do |barcode|
      barcode.emit_data_to_user
    end
    CsvProductImport.where("status != 'completed' AND status != 'cancelled'").each do |product_import|
      product_import.emit_data_to_user
    end
    import_summary = OrderImportSummary.top_summary
    unless import_summary.nil?
      import_summary.emit_data_to_user(true)
    end
    render json: {status: true}
  end
end
