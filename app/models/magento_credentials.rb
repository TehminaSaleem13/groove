# frozen_string_literal: true

class MagentoCredentials < ActiveRecord::Base
  # attr_accessible :host, :password, :username, :api_key, :import_products, :import_images, :push_tracking_number, :status_to_update, :enable_status_update, :shall_import_fraud, :shall_import_complete, :shall_import_closed, :shall_import_pending, :shall_import_processing, :updated_patch

  # validates_presence_of :host, :username, :api_key

  belongs_to :store

  before_save :check_value_of_status_to_update

  after_save :schedule_magento_status_update_job
  after_destroy :delete_magento_status_update_job

  private

  def check_value_of_status_to_update
    self.status_to_update = 'complete' if [nil, '', 'null', 'undefined'].include?(status_to_update)
  end

  def schedule_magento_status_update_job
    return true unless saved_changes['enable_status_update'].present?

    current_tenant = Apartment::Tenant.current
    tenant = Tenant.find_by_name(current_tenant)
    if enable_status_update && get_scheduled_jobs_for_status_update.blank?
      tenant.update_attributes(magento_tracking_push_enabled: true)
      # MagentoSoapOrders.new(tenant: current_tenant).schedule!
    else
      tenant.update_attributes(magento_tracking_push_enabled: false)
      # delete_magento_status_update_job
    end
  end

  def delete_magento_status_update_job
    return if magento_stores_present_for_status_update

    delayed_jobs = get_scheduled_jobs_for_status_update
    delayed_jobs.destroy_all
  end

  def get_scheduled_jobs_for_status_update
    current_tenant = Apartment::Tenant.current
    Delayed::Job.where("queue='update_magento_orders_status' and handler like ?", "%#{current_tenant}%")
   end

  def magento_stores_present_for_status_update
    magento_stores = Store.where('store_type=? and status=? and store_id!=?', 'Magento', true, id)
    magento_stores = Store.joins(:magento_credentials).where('store_type=? and status=? and stores.id!=? and magento_credentials.enable_status_update=?', 'Magento', true, store_id, true)
    magento_stores.present?
  end
end
