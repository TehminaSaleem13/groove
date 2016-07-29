class SettingsController < ApplicationController
  before_filter :groovepacker_authorize!
  include SettingsHelper

  def restore
    @result = SettingsService::Restore.call(
      current_user: current_user,
      params: params
    ).result
    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def export_csv
    puts 'export_csv'
    @result = {}
    @result['status'] = true
    @result['messages'] = []
    if current_user.can?('create_backups')
      GrooveBulkActions.execute_groove_bulk_action('export', params, current_user)
    else
      @result['status'] &= false
      @result['messages'] = ['You do not have enough permissions to backup and restore']
    end
    # if current_user.can? 'create_backups'
    #   dir = Dir.mktmpdir([current_user.username+'groov-export-', Time.now.to_s])
    #   filename = 'groove-export-'+Time.now.to_s+'.zip'
    #   begin
    #     data = zip_to_files(filename, Product.to_csv(dir))

    #   ensure
    #     FileUtils.remove_entry_secure dir
    #   end
    # else
    #   #prevent a fail and send empty zip
    #   filename = 'insufficient_permissions.zip'
    #   data = zip_to_files(filename, {})
    # end
    puts '@result: ' + @result.inspect

    render json: @result
  end

  def order_exceptions
    result = SettingsService::OrderExceptionExport.call(
      current_user: current_user, params: params
    ).result
    send_csv_data(result)
  end

  def order_serials
    result = SettingsService::OrderSerialExport.call(
      current_user: current_user, params: params
    ).result
    send_csv_data(result)
  end

  def get_columns_state
    @result = {}
    @result['status'] = true
    if params[:identifier].blank?
      @result['messages'] = ['No Identifier for state preference given']
      @result['status'] &= false
    else
      preference = ColumnPreference.find_by_user_id_and_identifier(current_user.id, params[:identifier])
      @result['data'] = preference if preference.present?
    end
    render json: @result
  end

  def save_columns_state
    @result = { 'status' => true }
    if params[:identifier].blank?
      @result['messages'] = ['No Identifier for state preference given']
      @result['status'] &= false
    else
      preference = ColumnPreference.find_or_create_by_user_id_and_identifier(current_user.id, params[:identifier])
      preference.theads = params[:theads]
      preference.save!
    end

    render json: @result
  end

  def get_settings
    @result = {}
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = {}

    general_setting = GeneralSetting.all.first

    if general_setting.present?
      @result['data']['settings'] = general_setting
    else
      @result['status'] &= false
      @result['error_messages'] = [
        'No general settings available for the system. Contact administrator.'
      ]
    end

    render json: @result
  end

  def update_settings
    @result = {}
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    general_setting = GeneralSetting.all.first

    if general_setting.present?
      if current_user.can? 'edit_general_prefs'
        general_setting.attributes = permit_general_setting_params
        if general_setting.save
          @result['success_messages'] = ['Settings updated successfully.']
        else
          @result['status'] &= false
          @result['error_messages'] = ['Error saving general settings.']
        end
      else
        @result['status'] &= false
        @result['error_messages'] = ['You are not authorized to update general preferences.']
      end
    else
      @result['status'] &= false
      @result['error_messages'] = ['No general settings available for the system. Contact administrator.']
    end

    render json: @result
  end

  def cancel_bulk_action
    result = {
      'status' => true, 'success_messages' => [],
      'notice_messages' => [], 'error_messages' => [],
      'bulk_action_cancelled_ids' => []
    }

    if params[:id].present?
      params[:id].each do |bulk_action_id|
        update_bulk_action(bulk_action_id, result)
      end
    else
      result['status'] &= false
      result['error_messages'] = ['no id bulk action id provided']
    end

    render json: result
  end

  def get_scan_pack_settings
    @result = {}
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['settings'] = {}

    scan_pack_setting = ScanPackSetting.all.first

    if scan_pack_setting.present?
      @result['settings'] = scan_pack_setting
    else
      @result['status'] &= false
      @result['error_messages'] = ['No Scan Pack settings available for the system. Contact administrator.']
    end

    render json: @result
  end

  #This method will generate barcode pdf and upload it in S3 and return url from S3
  def print_action_barcode
    require 'wicked_pdf' 
    scan_pack_setting = ScanPackSetting.all.first
    @action_code = scan_pack_setting[params[:id]]
   
    scan_pack_object = ScanPack::Base.new
    action_view = scan_pack_object.do_get_action_view_object_for_html_rendering
    reader_file_path = scan_pack_object.do_get_pdf_file_path(@action_code)
    @tenant_name = Apartment::Tenant.current
    file_name = @tenant_name + Time.now.strftime('%d_%b_%Y_%I__%M_%p')
    pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}.pdf")
    pdf_html = action_view.render :template => "settings/action_barcodes.html.erb", :layout => nil, :locals => {:@action_code => @action_code}
    doc_pdf = WickedPdf.new.pdf_from_string(
       pdf_html,
      :inline => true,
      :save_only => false,
      :orientation => 'Portrait',
      :page_height => '1in',
      :page_width => '3in',
      :margin => {:top => '0',
                  :bottom => '0',
                  :left => '0',
                  :right => '0'}
    )
    File.open(reader_file_path, 'wb') do |file|
      file << doc_pdf
    end
    base_file_name = File.basename(pdf_path)
    pdf_file = File.open(reader_file_path)
    GroovS3.create_pdf(@tenant_name, base_file_name, pdf_file.read)
    pdf_file.close
    generate_barcode = ENV['S3_BASE_URL']+'/'+@tenant_name+'/pdf/'+base_file_name
    generate_barcode.save
    render json: {url: generate_barcode}
  end

  def update_scan_pack_settings
    @result = {
      'status' => true,
      'error_messages' => [],
      'success_messages' => [],
      'notice_messages' => []
    }

    scan_pack_setting = ScanPackSetting.all.first

    if scan_pack_setting.present?
      update_scan_pack_settings_attributes(scan_pack_setting)
    else
      @result['status'] &= false
      @result['error_messages'] = ['No Scan pack settings available for the system. Contact administrator.']
    end

    render json: @result
  end

  def send_test_mail
    LowInventoryLevel.notify(GeneralSetting.all.first, Apartment::Tenant.current).deliver
    render json: 'ok'
  end

  # def execute_in_bulk_action(activity)
  #   result = {}
  #   result['status'] = true
  #   result['messages'] = []
  #   if current_user.can?('create_backups')
  #     GrooveBulkActions.execute_groove_bulk_action(activity, params, current_user)
  #   else
  #     result['status'] = false
  #     result['messages'] = ['You do not have enough permissions to backup and restore']
  #   end
  #   result
  #   # respond_to do |format|
  #   #   format.html # show.html.erb
  #   #   format.json { render json: result }
  #   # end
  # end
end
