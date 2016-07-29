namespace :ftp_csv_file_import do
  desc "import file from server"
  task :ftp_import => :environment do
    current_time = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M")
    Tenant.all.each do |tenant|
      begin
        Apartment::Tenant.switch "#{tenant.name}"
        stores = Store.includes(:ftp_credential).where('store_type = ? && ftp_credentials.use_ftp_import = ?', 'CSV', true)
        if stores.present?
          puts "starting the rake task"
          ftp_csv_import = Groovepacker::Orders::Import.new
          if tenant.name == "unitedmedco" && current_time >= "05:00" && current_time <= "10:00"
            ftp_csv_import.delay(attempts: 4).import_ftp_order("unitedmedco")
          elsif current_time >= "08:00" && current_time <= "10:00"
            ftp_csv_import.delay(attempts: 4).import_ftp_order(tenant.name)
          else
            tenant_name = Rails.env=="production" ? "gp50" : "myplan"
            ftp_csv_import.delay(attempts: 4).import_ftp_order(tenant_name)
            break
          end
          puts "task complete"
        end
      rescue Exception => e
        puts e.message
      end
    end
  end
end
