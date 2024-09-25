# frozen_string_literal: true

namespace :doo do
  desc 'Schedule orders export email'
  task schedule_orders_export_email: :environment do
    if $redis.get('schedule_orders_export_email').blank?
      $redis.set('schedule_orders_export_email', true)
      $redis.expire('schedule_orders_export_email', 5400)
      failed_tenant = []
      scheduled_tenants = []
      tenants = Tenant.order(:name)
      tenants.find_each do |tenant|
        scheduled = ImportOrders.new.reschedule_job('export_order', tenant.name)
        Apartment::Tenant.switch! tenant.name
        Time.use_zone(GeneralSetting.new_time_zone) do
          export_settings = ExportSetting.all.first
          setting = export_settings.present? && export_settings.auto_email_export? && export_settings.order_export_email.present? && export_settings.should_export_orders(DateTime.now.in_time_zone + 1.day)
          job = Delayed::Job.where('queue LIKE ? and created_at >= ?', "%order_export_email_scheduled_#{tenant.name}%", DateTime.now.in_time_zone.strftime('%F'))
          failed_tenant << tenant.name if job.blank? && setting
          scheduled_tenants << "#{tenant.name} - #{job[0].id}" if scheduled[0]
          if failed_tenant.present?
            failed_tenant.each do |t|
              ImportOrders.new.reschedule_job('export_order', t)
            end
          end
        end
      rescue StandardError
      end
      ExportOrder.not_scheduled_emails(failed_tenant, scheduled_tenants).deliver if failed_tenant.present? || scheduled_tenants.present?
    end
    exit(1)
  end
end
