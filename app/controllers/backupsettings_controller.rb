class BackupsettingsController < ApplicationController
  before_filter :authenticate_user!
  def get_backup_settings
  	@result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    backup_setting = BackupSetting.all.first

    if !backup_setting.nil?
      @result['data']['settings'] = backup_setting
    else
      @result['status'] &= false
      @result['error_messages'].push('No backup settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def update_backup_settings
  	@result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    backup_setting = BackupSetting.all.first

    if !backup_setting.nil?
      if current_user.can? 'edit_general_prefs'
        backup_setting.auto_email_export = params[:auto_email_export]
        backup_setting.time_to_send_export_email = params[:time_to_send_export_email]
        backup_setting.last_exported = params[:last_exported]
        backup_setting.export_orders_option = params[:export_orders_option]
        backup_setting.order_export_type = params[:order_export_type]
        backup_setting.order_export_email = params[:order_export_email]
        backup_setting.send_export_email_on_mon = params[:send_export_email_on_mon]
        backup_setting.send_export_email_on_tue = params[:send_export_email_on_tue]
        backup_setting.send_export_email_on_wed = params[:send_export_email_on_wed]
        backup_setting.send_export_email_on_thu = params[:send_export_email_on_thu]
        backup_setting.send_export_email_on_fri = params[:send_export_email_on_fri]
        backup_setting.send_export_email_on_sat = params[:send_export_email_on_sat]
        backup_setting.send_export_email_on_sun = params[:send_export_email_on_sun]

        if backup_setting.save
          @result['success_messages'].push('Backup settings updated successfully.')
        else
          @result['status'] &= false
          @result['error_messages'].push('Error saving backup settings.')
        end
      else
       @result['status'] &= false
       @result['error_messages'].push('You are not authorized to update backup preferences.')
      end
    else
      @result['status'] &= false
      @result['error_messages'].push('No backup settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end
end