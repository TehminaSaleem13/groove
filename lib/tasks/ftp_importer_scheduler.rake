namespace :product_ftp_csv_file_import do
  desc "import file from server"
  task :ftp_product_import => :environment do
  # current_time = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M")
    Tenant.all.each do |tenant|
      begin
        Apartment::Tenant.switch! "#{tenant.name}"
          puts "====================Product FTP import started for #{tenant.name}======================"
          Groovepacker::Products::Products.new.ftp_product_import(tenant.name) if tenant.product_ftp_import
          puts "====================Product FTP import end for #{tenant.name}======================"
      rescue Exception => e
          puts e.message
      end
    end
    puts "task complete"
    exit(1)
  end 
end