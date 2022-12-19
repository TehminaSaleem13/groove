# frozen_string_literal: true

namespace :doo do
  desc 'Create CSV and save to S3 and email'

  task export_import_log: :environment do
    [1, 2].each do |order|
      %w[unitedmedco sunlessinc janinetait brokencoast].each do |tenant|
        file_response = begin
                     File.read("#{Rails.root}/log/qty_csv_import_#{order}_#{tenant}.log")
                        rescue StandardError
                          nil
                   end
        next unless file_response.present?

        file_name = "#{tenant}_import_log_#{Time.current.strftime('%Y_%d_%m')}"
        GroovS3.create_csv(tenant, file_name, 1, file_response, :public_read)
        url = GroovS3.find_csv(tenant, file_name, 1).url.gsub('http:', 'https:')
        import = (order == '1' ? 'Import' : 'ReImport')
        CsvExportMailer.import_log(url, tenant, import).deliver
      end
    end
    %w[shipstation_order_import shipstation_tag_order_import].each do |log_name|
      %w[lairdsuperfood gunmagwarehouse].each do |tenant|
        file_response = begin
                      File.read("#{Rails.root}/log/#{log_name}_#{order}_#{tenant}.log")
                        rescue StandardError
                          nil
                    end
        next unless file_response.present?

        file_name = "#{tenant}_#{log_name}_#{Time.current.strftime('%Y_%d_%m')}"
        GroovS3.create_csv(tenant, file_name, 1, file_response, :public_read)
        url = GroovS3.find_csv(tenant, file_name, 1).url.gsub('http:', 'https:')
        CsvExportMailer.import_log(url, tenant, log_name.tr('_', ' ')).deliver
      end
    end
    file_response = begin
                         File.read("#{Rails.root}/log/export_report_scanned_on_time.log")
                    rescue StandardError
                      nil
                       end
    Apartment::Tenant.switch!
    if file_response.present?
      GroovS3.create_csv(Apartment::Tenant.current, "export_log_#{DateTime.now.in_time_zone}", 1, file_response, :public_read)
      url = GroovS3.find_csv(Apartment::Tenant.current, "export_log_#{DateTime.now.in_time_zone}", 1).try(:url)
      CsvExportMailer.export_scanned_time_log(url).deliver
    end
    exit(1)
  end
end
