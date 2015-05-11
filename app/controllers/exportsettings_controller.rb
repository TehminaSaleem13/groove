class ExportsettingsController < ApplicationController
  before_filter :authenticate_user!
  def get_export_settings
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    export_setting = ExportSetting.all.first
    export_setting.order_export_email = GeneralSetting.all.first.admin_email if export_setting.order_export_email.nil?
    export_setting.save
    unless export_setting.nil?
      @result['data']['settings'] = export_setting
    else
      @result['status'] &= false
      @result['error_messages'].push('No export settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def update_export_settings
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    export_setting = ExportSetting.all.first

    if !export_setting.nil?
      if current_user.can? 'edit_general_prefs'
        export_setting.auto_email_export = params[:auto_email_export]
        export_setting.time_to_send_export_email = params[:time_to_send_export_email]
        export_setting.last_exported = params[:last_exported]
        export_setting.export_orders_option = params[:export_orders_option]
        export_setting.order_export_type = params[:order_export_type]
        export_setting.order_export_email = params[:order_export_email]
        export_setting.send_export_email_on_mon = params[:send_export_email_on_mon]
        export_setting.send_export_email_on_tue = params[:send_export_email_on_tue]
        export_setting.send_export_email_on_wed = params[:send_export_email_on_wed]
        export_setting.send_export_email_on_thu = params[:send_export_email_on_thu]
        export_setting.send_export_email_on_fri = params[:send_export_email_on_fri]
        export_setting.send_export_email_on_sat = params[:send_export_email_on_sat]
        export_setting.send_export_email_on_sun = params[:send_export_email_on_sun]

        if export_setting.save
          @result['success_messages'].push('Export settings updated successfully.')
        else
          @result['status'] &= false
          @result['error_messages'].push('Error saving export settings.')
        end
      else
       @result['status'] &= false
       @result['error_messages'].push('You are not authorized to update export preferences.')
      end
    else
      @result['status'] &= false
      @result['error_messages'].push('No export settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def order_exports
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'view_packing_ex'
      if params[:start].nil? || params[:end].nil?
        result['status'] = false
        result['messages'].push('We need a start and an end time')
      else
        export_setting = ExportSetting.all.first
        export_setting.start_time = Time.parse(params[:start])
        export_setting.end_time = Time.parse(params[:end])
        export_setting.manual_export = true
        export_setting.save
        filename = "#{Rails.root}/public/csv/"+export_setting.export_data
        export_setting.manual_export = false
        export_setting.save
      end
    end
    unless result['status']
      data = CSV.generate do |csv|
        csv << result['messages']
      end
      filename = 'error.csv'
    end
    send_file filename, :type => 'text/csv'
  end
end
