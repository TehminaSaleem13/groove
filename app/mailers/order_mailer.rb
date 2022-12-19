# frozen_string_literal: true

class OrderMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def notify_packing_cam(order_id, tenant)
    Apartment::Tenant.switch! tenant
    @order = Order.find order_id
    @setting = ScanPackSetting.last
    subject = @setting.email_subject.to_s.gsub('[[ORDER-NUMBER]]', @order.increment_id)
    mail to: @order.email, subject: subject
  rescue StandardError => e
    puts e.to_s
  end
end
