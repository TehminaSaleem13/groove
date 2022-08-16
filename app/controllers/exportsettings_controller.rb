class ExportsettingsController < ApplicationController
  before_action :groovepacker_authorize!

  def get_export_settings
    @result = build_result_hash

    @export_setting = ExportSetting.first
    
    if @export_setting
      if @export_setting.order_export_email.nil?
        @export_setting.order_export_email = GeneralSetting.first.admin_email
        @export_setting.save
      end
      @result['data']['settings'] = @export_setting
      @result['data']['ftp_settings'] = FtpCredential.find_or_create_by(store_id: Store.find_by(store_type: 'system').id)
    else
      update_false_status(@result, 'No export settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def update_export_settings
    @result = build_result_hash

    @export_setting = ExportSetting.first

    if @export_setting
      if current_user.can? 'edit_general_prefs'
        @export_setting.auto_email_export =  params[:auto_email_export] unless params[:auto_email_export].nil?
        @export_setting.time_to_send_export_email = params[:time_to_send_export_email] unless params[:time_to_send_export_email].nil?
        @export_setting.last_exported = params[:last_exported] unless [:last_exported].nil?
        @export_setting.export_orders_option = params[:export_orders_option] unless params[:export_orders_option].nil?
        @export_setting.order_export_type = params[:order_export_type] unless params[:order_export_type].nil?
        @export_setting.order_export_email = params[:order_export_email] unless params[:order_export_email].nil?
        @export_setting.send_export_email_on_mon = params[:send_export_email_on_mon] unless params[:send_export_email_on_mon].nil?
        @export_setting.send_export_email_on_tue = params[:send_export_email_on_tue] unless params[:send_export_email_on_tue].nil?
        @export_setting.send_export_email_on_wed = params[:send_export_email_on_wed] unless params[:send_export_email_on_wed].nil?
        @export_setting.send_export_email_on_thu = params[:send_export_email_on_thu] unless params[:send_export_email_on_thu].nil?
        @export_setting.send_export_email_on_fri = params[:send_export_email_on_fri] unless params[:send_export_email_on_fri].nil?
        @export_setting.send_export_email_on_sat = params[:send_export_email_on_sat] unless params[:send_export_email_on_sat].nil?
        @export_setting.send_export_email_on_sun = params[:send_export_email_on_sun] unless params[:send_export_email_on_sun].nil?
        @export_setting.send_stat_export_email_on_mon = params[:send_stat_export_email_on_mon] unless params[:send_stat_export_email_on_mon].nil?
        @export_setting.send_stat_export_email_on_tue = params[:send_stat_export_email_on_tue] unless params[:send_stat_export_email_on_tue].nil?
        @export_setting.send_stat_export_email_on_wed = params[:send_stat_export_email_on_wed] unless params[:send_stat_export_email_on_wed].nil?
        @export_setting.send_stat_export_email_on_thu = params[:send_stat_export_email_on_thu] unless params[:send_stat_export_email_on_thu].nil?
        @export_setting.send_stat_export_email_on_fri = params[:send_stat_export_email_on_fri] unless params[:send_stat_export_email_on_fri].nil? 
        @export_setting.send_stat_export_email_on_sat = params[:send_stat_export_email_on_sat] unless params[:send_stat_export_email_on_sat].nil?
        @export_setting.send_stat_export_email_on_sun = params[:send_stat_export_email_on_sun] unless params[:send_stat_export_email_on_sun].nil?
        @export_setting.auto_stat_email_export = params[:auto_stat_email_export] unless params[:auto_stat_email_export].nil?
        @export_setting.time_to_send_stat_export_email = params[:time_to_send_stat_export_email] unless params[:time_to_send_stat_export_email].nil?
        @export_setting.stat_export_type = params[:stat_export_type] unless params[:stat_export_type].nil?
        @export_setting.stat_export_email = params[:stat_export_email] unless params[:stat_export_email].nil?
        @export_setting.processing_time = params[:processing_time] unless params[:processing_time].nil?
        @export_setting.daily_packed_email_export = params[:daily_packed_email_export] unless params[:daily_packed_email_export].nil?
        @export_setting.time_to_send_daily_packed_export_email = params[:time_to_send_daily_packed_export_email] unless params[:time_to_send_daily_packed_export_email].nil?
        @export_setting.daily_packed_email_on_mon = params[:daily_packed_email_on_mon] unless params[:daily_packed_email_on_mon].nil?
        @export_setting.daily_packed_email_on_tue = params[:daily_packed_email_on_tue] unless params[:daily_packed_email_on_tue].nil?
        @export_setting.daily_packed_email_on_wed = params[:daily_packed_email_on_wed] unless params[:daily_packed_email_on_wed].nil?
        @export_setting.daily_packed_email_on_thu = params[:daily_packed_email_on_thu] unless params[:daily_packed_email_on_thu].nil?
        @export_setting.daily_packed_email_on_fri = params[:daily_packed_email_on_fri] unless params[:daily_packed_email_on_fri].nil?
        @export_setting.daily_packed_email_on_sat = params[:daily_packed_email_on_sat] unless params[:daily_packed_email_on_sat].nil?
        @export_setting.daily_packed_email_on_sun = params[:daily_packed_email_on_sun] unless params[:daily_packed_email_on_sun].nil?
        @export_setting.daily_packed_email = params[:daily_packed_email] unless params[:daily_packed_email].nil? 
        @export_setting.daily_packed_export_type = params[:daily_packed_export_type] unless params[:daily_packed_export_type].nil?
        @export_setting.auto_ftp_export = params[:auto_ftp_export] unless params[:auto_ftp_export].nil?
        @export_setting.include_partially_scanned_orders = params[:include_partially_scanned_orders] unless params[:include_partially_scanned_orders].nil?
        @export_setting.save
        update_ftp_creds(params) if params[:auto_ftp_export]
        @result['success_messages'].push('Export settings updated successfully.')
        # else
        #   update_false_status(@result, 'Error saving export settings.')
        # end
      else
        update_false_status(@result, 'You are not authorized to update export preferences.')
      end
    else
      update_false_status(@result, 'No export settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def order_exports
    require 'csv'
    result = build_result_hash
    if current_user.can? 'view_packing_ex'
      if params[:start] && params[:end]
        export_setting = ExportSetting.first
        export_setting.update_attributes(
          start_time: Time.parse(params[:start]),
          end_time: Time.parse(params[:end]),
          manual_export: true
          )
        # export_setting.export_data(Apartment::Tenant.current)
        # export_setting.update_attributes(manual_export: false)
        ExportOrder.delay(priority: 95).export(Apartment::Tenant.current)
      else
        update_false_status(result, 'We need a start and an end time')
      end
    end
    unless result['status']
      CSV.open(Rails.root.join('public', 'csv', filename), 'wb') do |csv|
        csv << result['error_messages']
      end
      public_url = GroovS3.get_csv_export_exception(filename)

      filename = {url: public_url, filename: filename}
    end
    render json: result
    # send_file filename, :type => 'text/csv'
  end

  def email_stats
    stat_stream_obj = SendStatStream.new()
    export_setting = ExportSetting.first
    params = {"duration"=>export_setting.stat_export_type.to_i, "email"=>export_setting.stat_export_email}
    stat_stream_obj.delay(:queue => "generate_stat_export_#{Apartment::Tenant.current}", priority: 95).generate_export(Apartment::Tenant.current, params)
    render json: {}
  end

  def daily_packed
    daily_pack  = DailyPacked.new()
    daily_pack.delay(:queue => "generate_daily_packed_export_#{Apartment::Tenant.current}", priority: 95).send_daily_pack_csv(Apartment::Tenant.current)
    render json: {}
  end

  private

  def update_false_status(result, message)
    result['status'] = false
    result['error_messages'].push(message)
  end

  def update_ftp_creds(params)
    ftp_credential = FtpCredential.find_or_create_by(store_id: Store.find_by(store_type: 'system').id)
    ftp_credential.update(host: params[:host], username: params[:username], password: params[:password], connection_method: params[:connection_method])
  end

  def build_result_hash
    {
      'status' => true,
      'error_messages' => [],
      'success_messages' => [],
      'notice_messages' => [],
      'data' => {}
    }
  end
end
