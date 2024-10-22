class Webhooks::ShipstationController < ApplicationController
  before_action :set_store

  def import
    Groovepacker::LogglyLogger.log(Apartment::Tenant.current, "ss-webhook-import-order", { params: params })
    end_point = URI.parse(params['resource_url']).query
    import_orders = ImportOrders.new
    import_orders.delay(priority: 95, queue: "process_ss_webhook_import_order_#{Apartment::Tenant.current}").import_ss_webhook_order(end_point, params['resource_type'], @store.id, Apartment::Tenant.current) if end_point.present?

    head :ok
  end

  private

  def set_store
    @store = Store.joins(:shipstation_rest_credential).find_by(shipstation_rest_credentials: { id: params[:credential_id], webhook_secret: params[:secret].to_s }, store_type: 'Shipstation API 2')
    head :ok unless @store
  end
end
