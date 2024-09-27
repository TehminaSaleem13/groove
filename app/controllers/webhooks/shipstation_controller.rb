class Webhooks::ShipstationController < ApplicationController
  before_action :set_store

  def import
    end_point = URI.parse(params['resource_url']).query

    import_item = ImportItem.create(store_id: @store.id, status: 'webhook')
    handler = Groovepacker::Utilities::Base.new.get_handler(@store.store_type, @store, import_item)
    context = Groovepacker::Stores::Context.new(handler)

    context.delay(queue: 'process_ss_webhook_import_order', priority: 95).process_ss_webhook_import_order(end_point, params['resource_type']) if end_point.present?

    head :ok
  end

  private

  def set_store
    @store = Store.joins(:shipstation_rest_credential).find_by(shipstation_rest_credentials: { id: params[:credential_id], webhook_secret: params[:secret].to_s }, store_type: 'Shipstation API 2')
    head :ok unless @store
  end
end
