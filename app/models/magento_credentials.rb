class MagentoCredentials < ActiveRecord::Base

  attr_accessible :host, :password, :username, :api_key, :import_products, :import_images

  validates_presence_of :host, :username, :api_key

  belongs_to :store

  before_save :check_value_of_status_to_update

  after_save :schedule_magento_status_update_job
  after_destroy :delete_magento_status_update_job

  private

    def check_value_of_status_to_update
      self.status_to_update = "complete" if [nil, "", "null", "undefined"].include?(self.status_to_update)
    end

    def schedule_magento_status_update_job
      return true unless self.changes["enable_status_update"].present?
      current_tenant = Apartment::Tenant.current
      if self.enable_status_update and get_scheduled_jobs_for_status_update.blank?
      	MagentoSoapOrders.new(tenant: current_tenant).schedule!
      else
      	delete_magento_status_update_job
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
      magento_stores = Store.where("store_type=? and status=? and store_id!=?", 'Magento', true, self.id)
      magento_stores = Store.joins(:magento_credentials).where("store_type=? and status=? and stores.id!=? and magento_credentials.enable_status_update=?", 'Magento', true, self.store_id, true)
      magento_stores.present?
    end
end
