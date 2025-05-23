# frozen_string_literal: true

namespace :ftp_csv_file_import do
  desc 'import file from server'
  task ftp_import: :environment do
    next if $redis.get('import_file_from_server')

    $redis.set('import_file_from_server', true)
    $redis.expire('import_file_from_server', 180)
    # current_time = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M")
    Tenant.order(:name).find_each do |tenant|
      Apartment::Tenant.switch! tenant.name.to_s
      Time.use_zone(GeneralSetting.new_time_zone) do
        import_no_inprogress = OrderImportSummary.where('status in (?) and updated_at >= ?', %w[in_progress not_started], (DateTime.now.in_time_zone - 1.hour)).none?
        item = ImportItem.joins(:store).where(stores: { store_type: 'CSV' }).where(status: 'in_progress').none?
        puts "====================FTP import for #{tenant.name}======================"
        # cred = !Store.where("csv_beta = ? and status = ?", true, true).map(&:ftp_credential).map(&:use_ftp_import).include?(true) rescue true
        if import_no_inprogress && item
          puts 'starting the rake task'
          general_setting = GeneralSetting.last
          current_time = Time.current.strftime('%H:%M')
          from_import = general_setting.from_import.strftime('%H:%M')
          to_import = general_setting.to_import.strftime('%H:%M')
          ftp_csv_import = Groovepacker::Orders::Import.new
          #   if tenant.name == "unitedmedco" && current_time >= "05:00" && current_time <= "12:00"
          #     # ftp_csv_import.delay(attempts: 4).import_ftp_order("unitedmedco")
          #     ftp_csv_import.ftp_order_import("unitedmedco")
          #   elsif current_time >= "08:00" && current_time <= "12:00"
          if current_time >= from_import && current_time <= to_import
            OrderImportSummary.destroy_all if tenant.name == 'unitedmedco'
            # ftp_csv_import.delay(attempts: 4).import_ftp_order(tenant.name)
            puts "Current Time: #{current_time} / From Import: #{from_import} / To Import: #{to_import}"
            ftp_csv_import.ftp_order_import(tenant.name)
          end
        end
        puts "====================Product FTP import started for #{tenant.name}======================"
        Groovepacker::Products::Products.new.ftp_product_import(tenant.name) if tenant.product_ftp_import
        puts "====================Product FTP import end for #{tenant.name}======================"
      end
    rescue Exception => e
      puts e.message
    end
    puts 'task complete'
    exit(1)
  end
end
