namespace :check do
  desc "check UMI import"
  task :umi_import => :environment do
  tenant = "unitedmedco"
  Apartment::Tenant.switch tenant
  import_item = ImportItem.includes(:store).where("stores.store_type='CSV' and (import_items.status='in_progress' OR import_items.status='not_started')")
    begin
      import_item.each do |csv_import|
        if (Time.now.to_i - csv_import.updated_at.to_i) > 300
          csv_import.update_attribute(:status, "cancelled")
          summary = csv_import.order_import_summary
          summary.status = "completed"
          summary.save
          ImportMailer.import_hung(tenant, csv_import).deliver
        end
      end
    rescue
    end
  end
end
