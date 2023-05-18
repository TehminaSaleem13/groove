# frozen_string_literal: true

namespace :doo do
  desc 'Schedule inventory email'
  task schedule_inventory_report: :environment do
    if $redis.get('schedule_inventory_report').blank?
      $redis.set('schedule_inventory_report', true)
      $redis.expire('schedule_inventory_report', 5400)
      failed_tenant = []
      tenants = Tenant.order(:name)
      import_orders_obj = ImportOrders.new
      tenants.each do |tenant|
        import_orders_obj.reschedule_job('inv_report', tenant.name)
      rescue StandardError => e
        puts e
      end
    end
    exit(1)
  end
end
