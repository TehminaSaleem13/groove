# frozen_string_literal: true

namespace :check do
  desc 'check UMI import'
  task umi_import: :environment do
    tenant = 'unitedmedco'
    # if Rails.env=="production"
    Apartment::Tenant.switch! tenant
    Time.use_zone(GeneralSetting.new_time_zone) do
      import_item = ImportItem.joins(:store).where("stores.store_type='CSV' and (import_items.status='in_progress' OR import_items.status='not_started')")
      begin
        import_item.each do |csv_import|
          next unless (Time.current.to_i - csv_import.updated_at.to_i) > 600

          time_of_import = csv_import.created_at
          file_name = $redis.get("file_name_#{tenant}")
          log = AddLogCsv.new
          log.add_log_csv(Apartment::Tenant.current, time_of_import, file_name)
          csv_import.update_attribute(:status, 'cancelled')
          summary = csv_import.order_import_summary
          summary.status = 'completed'
          summary.save
          OrderImportSummary.destroy_all
          ImportMailer.import_hung(tenant, csv_import).deliver
        end
      rescue StandardError
      end
    end
    # end
  end
end
