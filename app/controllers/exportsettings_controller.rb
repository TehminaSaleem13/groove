class ExportsettingsController < ApplicationController
  before_filter :groovepacker_authorize!

  def get_export_settings
    @result = build_result_hash

    @export_setting = ExportSetting.first
    
    if @export_setting
      if @export_setting.order_export_email.nil?
        @export_setting.order_export_email = GeneralSetting.first.admin_email
        @export_setting.save
      end
      @result['data']['settings'] = @export_setting
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
        @export_setting.update_attributes(
          auto_email_export: params[:auto_email_export],
          time_to_send_export_email: params[:time_to_send_export_email],
          last_exported: params[:last_exported],
          export_orders_option: params[:export_orders_option],
          order_export_type: params[:order_export_type],
          order_export_email: params[:order_export_email],
          send_export_email_on_mon: params[:send_export_email_on_mon],
          send_export_email_on_tue: params[:send_export_email_on_tue],
          send_export_email_on_wed: params[:send_export_email_on_wed],
          send_export_email_on_thu: params[:send_export_email_on_thu],
          send_export_email_on_fri: params[:send_export_email_on_fri],
          send_export_email_on_sat: params[:send_export_email_on_sat],
          send_export_email_on_sun: params[:send_export_email_on_sun]
          )
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
        ExportOrder.delay.export(Apartment::Tenant.current)
      else
        update_false_status(result, 'We need a start and an end time')
      end
    end
    unless result['status']
      CSV.generate do |csv|
        csv << result['error_messages']
      end
      filename = 'error.csv'
    end
    render json: result
    # send_file filename, :type => 'text/csv'
  end

  private

  def update_false_status(result, message)
    result['status'] = false
    result['error_messages'].push(message)
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
