namespace :ftp_import_verification do
  desc 'FTP Import Verification'
  task :verify_import => :environment do
    Tenant.where(name: 'gp50').each do |tenant|
      begin
        Apartment::Tenant.switch! tenant.name
        VerifyFtpOrders.new.initiate_import_verification(tenant.name)
      rescue Exception => e
        puts e.message
      end
    end
    puts 'task complete'
    exit(1)
  end
end
