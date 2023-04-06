# frozen_string_literal: true

namespace :doo do
  desc 'delete ftp files older than 90 days'
  task delete_older_ftp_files: :environment do
    Tenant.all.each do |tenant|
      Apartment::Tenant.switch! tenant.name.to_s

      Store.where(store_type: "CSV", status: true).each do |store|
        # FTP Older Order Deletion
        begin
          groove_ftp = FTP::FtpConnectionManager.get_instance(store)
          puts groove_ftp.delete_older_files
        rescue StandardError => e
          puts 'Order Files Deletion Failed for  ' + tenant.name.to_s
          puts e.message
        end
        # FTP Older Product Deletion
        begin
          groove_ftp = FTP::FtpConnectionManager.get_instance(store, 'product')
          puts groove_ftp.delete_older_files
        rescue StandardError => e
          puts 'Product Files Deletion Failed for  ' + tenant.name.to_s
          puts e.message
        end
      end
    rescue Exception => e
      puts e.message
    end
    puts 'task complete'
    exit(1)
  end
end
