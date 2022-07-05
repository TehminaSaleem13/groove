class PackingCam < ApplicationRecord
  belongs_to :order
  belongs_to :user
  belongs_to :order_item, optional: true

  validates_presence_of :url

  after_create :notify_user

  def notify_user
    tenant = Tenant.find_by name: Apartment::Tenant.current
    scan_pack_setting = ScanPackSetting.last
    return unless tenant&.packing_cam?

    return unless scan_pack_setting&.packing_cam_enabled? && scan_pack_setting&.email_customer_option?

    return unless order&.scanned? && order&.email.present?

    # OrderMailer.notify_packing_cam(order.id, tenant&.name)
    OrderMailer.delay(priority: 95).notify_packing_cam(order.id, tenant&.name)
  end
end
