
class ImportOrdersJob < ActiveJob::Base
    queue_as :default
  
    def perform(store_name, current_tenant, import_type, days)
      return if current_tenant.blank?
      
      Apartment::Tenant.switch!(current_tenant)
      store_from_cred = ShopifyCredential.find_by(shop_name: store_name).store
      return if store_from_cred.blank?
      store_id = store_from_cred.id

     if  ImportItem.where('status NOT IN (?) AND store_id = ?', %w[cancelled completed failed], store_id).blank?
       Delayed::Job.where(queue: 'importing_orders_' + current_tenant).destroy_all
       import_params = { tenant: current_tenant, store: store_from_cred, import_type: import_type, user: nil, days: days }
       ImportOrders.new.import_order_by_store(import_params)
     end
    end
  end