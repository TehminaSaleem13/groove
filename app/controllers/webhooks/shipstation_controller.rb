class Webhooks::ShipstationController < ApplicationController
  before_action :set_store

  def import
    uri = URI.parse(params['resource_url'])
    path_url = uri.query
  
    import_item = ImportItem.create(store_id: @store.id, status: 'webhook')
    handler = Groovepacker::Utilities::Base.new.get_handler(@store.store_type, @store, import_item)
    context = Groovepacker::Stores::Context.new(handler)
  
    context.process_ss_webhook_import_order(path_url) if path_url.present?
  
    head :ok
  end  

  private

  def set_store
    @store = Store.joins(:shipstation_rest_credential).find_by(shipstation_rest_credentials: { id: params[:credential_id], webhook_secret: params[:secret].to_s }, store_type: 'Shipstation API 2')
    head :ok unless @store
  end
end
