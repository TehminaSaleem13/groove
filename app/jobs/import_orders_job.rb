
class ImportOrdersJob < ActiveJob::Base
  queue_as :default

  def perform(store_name, tenant, order_number)
    return unless Tenant.find_by_name(tenant)

    Apartment::Tenant.switch!(tenant)
    credential = ShopifyCredential.find_by(shop_name: store_name)
    return unless credential&.webhook_order_import

    import_item = ImportItem.create(store_id: credential.store_id, status: 'webhook')
    handler = Groovepacker::Utilities::Base.new.get_handler(credential.store.store_type, credential.store, import_item)
    context = Groovepacker::Stores::Context.new(handler)
    context.import_single_order_from(order_number)
  end
end
