# frozen_string_literal: true

namespace :doo do
  desc 'delete ftp files older than 90 days'
  task delete_older_ftp_files: :environment do
    next if $redis.get('delete_ftp_files_older_than_90_days')

    $redis.set('delete_ftp_files_older_than_90_days', true)
    $redis.expire('delete_ftp_files_older_than_90_days', 180)
    Tenant.find_each do |tenant|
      Apartment::Tenant.switch! tenant.name.to_s

      Store.where(store_type: "CSV", status: true).each do |store|
        # FTP Older Order Deletion
        if store.ftp_credential.use_ftp_import
          begin
            groove_ftp = FTP::FtpConnectionManager.get_instance(store)
            puts groove_ftp.delete_older_files
          rescue StandardError => e
            puts 'Order Files Deletion Failed for  ' + tenant.name.to_s
            puts e.message
          end 
        end
        # FTP Older Product Deletion
        if store.ftp_credential.use_product_ftp_import
          begin
            groove_ftp = FTP::FtpConnectionManager.get_instance(store, 'product')
            puts groove_ftp.delete_older_files
          rescue StandardError => e
            puts 'Product Files Deletion Failed for  ' + tenant.name.to_s
            puts e.message
          end
        end
      end
    rescue Exception => e
      puts e.message
    end
    puts 'task complete'
    exit(1)
  end
end
