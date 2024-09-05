# frozen_string_literal: true

namespace :check do
  desc 'check failed imports'
  task failed_imports: :environment do
    Tenant.order(:name).each do |tenant|
      Apartment::Tenant.switch! tenant.name
      import_items = ImportItem.joins(:store).where("stores.status=1 and (import_items.status='in_progress' OR import_items.status='not_started')").readonly(false)
      next unless import_items.any?

      in_progress_items = import_items.where(status: 'in_progress')
      not_started_items = import_items.where(status: 'not_started')
      begin
        failed_import_items = []
        in_progress_items.each do |import_item|
          next unless (Time.current.to_i - import_item.updated_at.to_i) > 90

          import_item.update(status: 'cancelled', message: 'Import Failed. Please try again.')
          begin
            import_item.order_import_summary.update(status: 'cancelled')
          rescue StandardError
            nil
          end
          failed_import_items << import_item
        end
        if failed_import_items.any?
          not_started_items.update_all(status: 'cancelled')
          begin
            OrderImportSummary.top_summary.emit_data_to_user(true)
          rescue StandardError
            nil
          end
          import_start_count = $redis.get("import_restarted_#{tenant.name}").to_i || 0
          if import_start_count < 3
            $redis.set("import_restarted_#{tenant.name}", import_start_count.to_i + 1)
            $redis.expire("import_restarted_#{tenant.name}", 30.minutes.to_i)
            OrderImportSummary.create(user_id: nil, status: 'not_started')
            ImportOrders.new.delay(run_at: 1.seconds.from_now, priority: 95).import_orders(tenant.name)
          else
            $redis.del("import_restarted_#{tenant.name}")
            ImportMailer.failed_imports(tenant.name, failed_import_items).deliver
          end
        end
      rescue StandardError
      end
    end
  end
end
