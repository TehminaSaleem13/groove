namespace :ftp_csv_file_import do
  desc "import file from server"
  task :ftp_import => :environment do
    current_time = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M")
    Tenant.all.each do |tenant|
      begin
        Apartment::Tenant.switch "#{tenant.name}"
        import_no_inprogress = OrderImportSummary.where(status: 'in_progress').blank?
        if import_no_inprogress
          puts "starting the rake task"
          ftp_csv_import = Groovepacker::Orders::Import.new
          if tenant.name == "unitedmedco" && current_time >= "05:00" && current_time <= "12:00"
            # ftp_csv_import.delay(attempts: 4).import_ftp_order("unitedmedco")
            ftp_csv_import.ftp_order_import("unitedmedco")
          elsif current_time >= "08:00" && current_time <= "12:00"
            # ftp_csv_import.delay(attempts: 4).import_ftp_order(tenant.name)
            ftp_csv_import.ftp_order_import(tenant.name)
          end
        end
      rescue Exception => e
        puts e.message
      end
    end
    puts "task complete"
    exit(1)
  end
end
