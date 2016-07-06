namespace :ftp_csv_file_import do
  desc "import file from server"
  task :ftp_import => :environment do
    Tenant.all.each do |tenant|
      begin
        puts "starting the rake task"
        ftp_csv_import = Groovepacker::Orders::Import.new
        ftp_csv_import.delay.import_ftp_order(tenant.name)
        puts "task complete"
      rescue Exception => e
        puts e.message
      end
    end
  end
end
