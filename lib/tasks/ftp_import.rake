namespace :ftp_csv_file_import do
  desc "import file from server"
  task :ftp_import => :environment do
    current_time = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M")
    umi_ftp_logger = Logger.new("#{Rails.root}/log/umi_ftp.log")
    other_tenants_logger = Logger.new("#{Rails.root}/log/ftp_tenant.log")
    ftp_error_logger = Logger.new("#{Rails.root}/log/ftp_error.log")
    Tenant.all.each do |tenant|
      begin
        Apartment::Tenant.switch "#{tenant.name}"
        import_no_inprogress = OrderImportSummary.where("status in (?) and updated_at >= ?", ['in_progress', "not_started"], (DateTime.now - 1.hour)).blank?
        item = !ImportItem.includes(:store).where(:stores => {:store_type => "CSV"}).map(&:status).include?("in_progress")
        # cred = !Store.where("csv_beta = ? and status = ?", true, true).map(&:ftp_credential).map(&:use_ftp_import).include?(true) rescue true
        # general_setting = GeneralSetting.last 
        puts "====================FTP import======================"
        # current_time = (Time.now.utc + general_setting.time_zone.to_i).strftime("%H:%M")
        # from_import = general_setting.from_import.strftime("%H:%M")
        # to_import = general_setting.to_import.strftime("%H:%M")
        other_tenants_logger.info("#{tenant.name} -  Current Time #{current_time} : UTC Time #{Time.now.utc} : ImportItem #{item.try(:status)} : OrderImportSummary #{import_no_inprogress.try(:status)}")
        if import_no_inprogress && item 
          puts "starting the rake task"
          ftp_csv_import = Groovepacker::Orders::Import.new
          if tenant.name == "unitedmedco" && current_time >= "05:00" && current_time <= "12:00"
            umi_ftp_logger.info("=========================================")
            umi_ftp_logger.info("Current Time #{current_time} : UTC Time #{Time.now.utc}")
            # ftp_csv_import.delay(attempts: 4).import_ftp_order("unitedmedco")
            ftp_csv_import.ftp_order_import("unitedmedco")
          elsif current_time >= "08:00" && current_time <= "12:00"
          # if current_time >= from_import && current_time <= to_import
            # ftp_csv_import.delay(attempts: 4).import_ftp_order(tenant.name)
            other_tenants_logger.info("=========================================")
            other_tenants_logger.info("#{tenant.name} -  Current Time #{current_time} : UTC Time #{Time.now.utc}")
            ftp_csv_import.ftp_order_import(tenant.name)
          end
        end
      rescue Exception => e
        ftp_error_logger.info("=========================================")
        ftp_error_logger.info("#{e.message}")
        puts e.message
      end
    end
    puts "task complete"
    exit(1)
  end
end


