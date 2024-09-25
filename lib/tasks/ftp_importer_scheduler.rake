# frozen_string_literal: true

namespace :product_ftp_csv_file_import do
  desc 'import file from server'
  task ftp_product_import: :environment do
    next if $redis.get('import_file_from_server')

    $redis.set('import_file_from_server', true)
    $redis.expire('import_file_from_server', 180)
    # current_time = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M")
    Tenant.find_each do |tenant|
      Apartment::Tenant.switch! tenant.name.to_s
      puts "====================Product FTP import started for #{tenant.name}======================"
      Groovepacker::Products::Products.new.ftp_product_import(tenant.name) if tenant.product_ftp_import
      puts "====================Product FTP import end for #{tenant.name}======================"
    rescue Exception => e
      puts e.message
    end
    puts 'task complete'
    exit(1)
  end
end
