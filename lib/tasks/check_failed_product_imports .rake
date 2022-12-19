# frozen_string_literal: true

namespace :check do
  desc 'check failed product imports'
  task failed_product_imports: :environment do
    Tenant.where(is_cf: true).each do |tenant|
      Apartment::Tenant.switch! tenant.name
      in_progress_items = StoreProductImport.where(status: 'in_progress')
      not_started_items = StoreProductImport.where(status: 'not_started')
      next if (not_started_items + in_progress_items).blank?

      begin
        failed_import_items = []
        in_progress_items.each do |import_item|
          failed_import_items << import_item if (Time.zone.now.to_i - import_item.updated_at.to_i) > 90
        end
        if failed_import_items.any?
          not_started_items.destroy_all
          failed_import_items.each do |import_item|
            dj = Delayed::Job.find(import_item.delayed_job_id)
            dj_args = dj.payload_object.args
            dj.destroy
            import_item.destroy
            store_product_import = StoreProductImport.create(store_id: dj_args[1], status: 'not_started')
            d_job = ImportOrders.new.delay(run_at: 1.seconds.from_now, queue: "import_shopify_products_#{dj_args[0]}", priority: 95).import_product_from_store(dj_args[0], dj_args[1], dj_args[2], dj_args[3])
            store_product_import.update(delayed_job_id: d_job.id)
          end
        elsif StoreProductImport.where(status: 'not_started').any?
          not_started_yet = StoreProductImport.where(status: 'not_started')
          not_started_yet.each do |import_item|
            dj = Delayed::Job.find(import_item.delayed_job_id)
            next unless (Time.zone.now.to_i - dj.updated_at.to_i) > 600

            dj_args = dj.payload_object.args
            dj.destroy
            import_item.destroy
            store_product_import = StoreProductImport.create(store_id: dj_args[1], status: 'not_started')
            d_job = ImportOrders.new.delay(run_at: 1.seconds.from_now, queue: "import_shopify_products_#{dj_args[0]}", priority: 95).import_product_from_store(dj_args[0], dj_args[1], dj_args[2], dj_args[3])
            store_product_import.update(delayed_job_id: d_job.id)
          end
        end
      rescue StandardError
      end
    end
  end
end
