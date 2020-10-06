class SettingsController < ApplicationController
  before_action :groovepacker_authorize!
  include SettingsHelper

  def restore
    data = File.read(params[:file].path)
    params[:file] = GroovS3.create_public_zip(Apartment::Tenant.current, data).url
    restore = SettingsService::Restore.new(
      current_user: current_user,
      params: params,
      tenant: Apartment::Tenant.current
    )
    @result = restore.delay.call
    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def export_csv
    puts 'export_csv'
    @result = {'status' => true, 'messages' => []}
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

    render json: @result
  end

  def order_exceptions
    result = SettingsService::OrderExceptionExport.call(
      current_user: current_user, params: params
    ).result
    # send_csv_data(result)
    render json: result
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
      preference = ColumnPreference.find_or_create_by(user_id: current_user.id, identifier: params[:identifier])
      preference.theads = params[:theads]
      preference.save!
    end

    render json: @result
  end

  def get_settings
    @result = {'status' => true, 'error_messages' => [], 'success_messages' => [], 'notice_messages' => [], 'data'=> {}}
    current_tenant = Tenant.find_by_name(Apartment::Tenant.current)
    @result['scheduled_import_toggle'] = current_tenant.scheduled_import_toggle rescue false
    @result['inventory_report_toggle'] = current_tenant.inventory_report_toggle rescue false
    @result['is_multi_box'] = current_tenant.is_multi_box rescue false
    @result['api_call'] = current_tenant.api_call rescue false
    @result['allow_rts'] = current_tenant.allow_rts rescue false
    @result['product_ftp_import'] = current_tenant.product_ftp_import rescue false
    @result['groovelytic_stat'] = current_tenant.groovelytic_stat rescue true
    @result['is_active'] = current_user.active
    @result['custom_product_fields'] = current_tenant.custom_product_fields rescue false
    @result['product_activity'] = current_tenant.product_activity_switch rescue false
    @result['time_zone'] = Groovepacks::Application.config.time_zones
    @result['user_sign_in_count'] = current_user.sign_in_count
    general_setting = GeneralSetting.all.first
    offset = general_setting.try(:time_zone).to_i
    offset = general_setting.try(:dst) ? offset : offset + 3600
    @result['current_time'] = (Time.current + offset).strftime('%I:%M %p')
    @result['time_zone_name'] = Groovepacks::Application.config.tz_abbreviations['tz_abbreviations'].key(general_setting.try(:time_zone).to_i)
    @result['scan_pack_workflow'] = Tenant.find_by_name(Apartment::Tenant.current).scan_pack_workflow rescue 'default'

    if general_setting.present?
      @result['data']['settings'] = general_setting
      @result['data']['settings'] = @result['data']['settings'].attributes.merge('packing_type'=> $redis.get("#{Apartment::Tenant.current}_packing_type"))
    else
      @result['status'] &= false
      @result['error_messages'] = ['No general settings available for the system. Contact administrator.']
    end
    @result["email_address_for_billing_notification"] = general_setting.email_address_for_billing_notification
    render json: @result
  end

  def find_stripe_customer
    tenant = Apartment::Tenant.current
    customer = Subscription.find_by_tenant_name(tenant) rescue nil
  end

  def update_settings
    @result = {'status' => true, 'error_messages' =>[], 'success_messages'=> [], 'notice_messages' => []}
    general_setting = GeneralSetting.all.first
    @result = upadate_setting_attributes(general_setting, current_user)
    customer = find_stripe_customer
    update_with_stripe_customer(customer) if general_setting.email_address_for_billing_notification != params[:email_address_for_billing_notification] && !general_setting.email_address_for_billing_notification.nil?
    render json: @result
  end

  def cancel_bulk_action
    result = {'status' => true, 'success_messages' => [],'notice_messages' => [], 'error_messages' => [],'bulk_action_cancelled_ids' => []}

    if params[:id].present?
      params[:id].each do |bulk_action_id|
        update_bulk_action(bulk_action_id, result)
      end
    else
      rem_bulkactions = GrooveBulkActions.where("status = 'pending' OR status = 'in_progress'")
      rem_bulkactions.each do |bulk_action|
        bulk_action.cancel = true
        bulk_action.status = 'cancelled'
        bulk_action.save
        $redis.del("bulk_action_delete_data_#{Apartment::Tenant.current}_#{bulk_action.id}")
        $redis.del("bulk_action_duplicate_data_#{Apartment::Tenant.current}_#{bulk_action.id}")
        $redis.del("bulk_action_data_#{Apartment::Tenant.current}_#{bulk_action.id}")
      end
      result['status'] &= false
      result['error_messages'] = ['no id bulk action id provided']
    end

    render json: result
  end

  def get_scan_pack_settings
    @result = {'status' => true, 'error_messages'=> [], 'success_messages'=> [], 'notice_messages' => [], 'settings'=> {}}
    scan_pack_setting = ScanPackSetting.all.first

    if scan_pack_setting.present?
      @result['settings'] = scan_pack_setting.as_json.merge!('scan_pack_workflow' => Tenant.find_by_name(Apartment::Tenant.current).scan_pack_workflow, 'tote_sets' => ToteSet.select("id, name, max_totes"))
    else
      @result['status'] &= false
      @result['error_messages'] = ['No Scan Pack settings available for the system. Contact administrator.']
    end

    render json: @result
  end

  def print_tote_barcodes
    require 'wicked_pdf'
    result = {}
    tote_set = ToteSet.find(params[:id])
    if tote_set.totes.any?
      action_view = ScanPack::Base.new.do_get_action_view_object_for_html_rendering
      file_name = Apartment::Tenant.current + Time.now.strftime('%d_%b_%Y_%I_%S_%M_%p') + "_tote_barcodes"
      reader_file_path = Rails.root.join('public', 'pdfs', "tote_barcodes.pdf")
      pdf_html = action_view.render :template => 'settings/tote_barcodes.html.erb', :layout => nil, :locals => {:@totes => tote_set.totes, :@tote_identifier => ScanPackSetting.last.tote_identifier.upcase}
      doc_pdf = WickedPdf.new.pdf_from_string(
        pdf_html,
       :inline => true,
       :save_only => false,
       :orientation => 'Portrait',
       :page_height => '4in',
       :page_width => '6in',
       :margin => {:top => '10', :bottom => '1', :left => '1', :right => '1'}
     )
     File.open(reader_file_path, 'wb') do |file|
       file << doc_pdf
     end
      pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}.pdf")
      base_file_name = File.basename(pdf_path)
      pdf_file = File.open(reader_file_path)
      GroovS3.create_pdf(Apartment::Tenant.current, base_file_name, pdf_file.read)
      pdf_file.close
      generate_url = ENV['S3_BASE_URL']+'/'+Apartment::Tenant.current+'/pdf/'+base_file_name
      result[:status] = true
      result[:url] = generate_url
    else
      result[:message] = 'No totes are present'
      result[:status] = false
    end
    render json: result
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
      :margin => {:top => '0', :bottom => '0',:left => '0',:right => '0'}
    )
    File.open(reader_file_path, 'wb') do |file|
      file << doc_pdf
    end
    base_file_name = File.basename(pdf_path)
    pdf_file = File.open(reader_file_path)
    GroovS3.create_pdf(@tenant_name, base_file_name, pdf_file.read)
    pdf_file.close
    generate_barcode = ENV['S3_BASE_URL']+'/'+@tenant_name+'/pdf/'+base_file_name
    # generate_barcode.save
    render json: {url: generate_barcode}
  end

  def update_scan_pack_settings
    @result = {'status' => true,'error_messages' => [],'success_messages' => [],'notice_messages' => []}

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

  def search_by_product
    setting = GeneralSetting.all.first
    search_toggle = !params["_json"]
    setting.search_by_product = search_toggle
    setting.save
    render json: @result
  end

  def fetch_and_update_time_zone
    setting = GeneralSetting.first
    setting.update_attribute(:dst, params["dst"].to_b ) if params["dst"]
    if params["add_time_zone"].present?
      if params["auto_detect"] == "true" || params["auto_detect"] == "false" && (params["add_time_zone"].include? ":")
        params["add_time_zone"] = convert_offset_in_second(params["add_time_zone"])
        setting.update_attributes(time_zone: params["add_time_zone"], auto_detect: true)
      elsif (!params["add_time_zone"].include? ":") && params["auto_detect"] != "true" && params["auto_detect"] != "false"
        setting.update_attributes(time_zone: params["add_time_zone"], auto_detect: false)
      end
      @result = {};
      offset = params["add_time_zone"].to_i
      offset = setting.dst ? offset : offset+3600
      @result['current_time'] = (Time.current + offset ).strftime('%I:%M %p')
      #@result['current_time'] = (Time.current + params["add_time_zone"].to_i).strftime('%I:%M %p')
    end

    render json: @result
  end

  def convert_offset_in_second(offset)
    minutes = offset.split("-")[1].present? ? -offset.split(":")[1].to_i*60 : offset.split(":")[1].to_i*60
    minutes + offset.split(":")[0].to_i*3600
  end

  def update_stat_status
    result = {}
    setting = GeneralSetting.all.first
    setting.update_attribute(:stat_status, "preparing to update") if params[:percentage].to_i == 0
    setting.update_attribute(:stat_status, nil) if params[:percentage].to_i.between?(1, 99)
    setting.update_attribute(:stat_status, "completed") if params[:percentage].to_i == 100
    result[:status] = "true"
    result[:stat_status] = setting.stat_status
    render json: result
  end

  def update_email_address_for_packer_notes
    setting = GeneralSetting.all.first
    setting.email_address_for_packer_notes = params["email"]
    setting.save
    render json: {}
  end

  def auto_complete
    data = []
    Tenant.select(:name).each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      if params[:type] == 'general_settings'

        data << GeneralSetting.select(:custom_user_field_one).where('custom_user_field_one LIKE ?', "%#{params[:value]}%").pluck(:custom_user_field_one)
        data << GeneralSetting.select(:custom_user_field_two).where('custom_user_field_two LIKE ?', "%#{params[:value]}%").pluck(:custom_user_field_two)
      else
        data << User.select(:custom_field_one).where('custom_field_one LIKE ?', "%#{params[:value]}%").pluck(:custom_field_one)
        data << User.select(:custom_field_two).where('custom_field_two LIKE ?', "%#{params[:value]}%").pluck(:custom_field_two)
      end
    end

    render json: data.flatten.uniq
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
