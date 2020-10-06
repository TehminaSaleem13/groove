class ShipstationRestCredential < ActiveRecord::Base
  # attr_accessible :api_key, :api_secret, :store_id, :shall_import_, :regular_import_range, :gen_barcode_from_sku, :import_upc, :allow_duplicate_order, :bulk_import, :quick_import_last_modified, :quick_import_last_modified_v2, :shall_import_awaiting_shipment, :shall_import_shipped, :warehouse_location_update, :shall_import_customer_notes, :shall_import_internal_notes, :shall_import_pending_fulfillment, :use_chrome_extention, :switch_back_button, :auto_click_create_label, :download_ss_image, :return_to_order, :tag_import_option, :order_import_range_days, :import_tracking_info
  validates_presence_of :regular_import_range
  before_save :check_if_null_or_undefined
  belongs_to :store

  
  def check_if_null_or_undefined
    self.api_key = nil if self.api_key=="null" or self.api_key=="undefined"
    self.api_secret = nil if self.api_secret=="null" or self.api_secret=="undefined"
  end

  def verify_tags
    context = Groovepacker::Stores::Context.new(
      Groovepacker::Stores::Handlers::ShipstationRestHandler.new(store))
    context.verify_tags([gp_ready_tag_name, gp_imported_tag_name, "GP READY", "GP IMPORTED"]) 
  end

  def verify_awaits_tag
    context = Groovepacker::Stores::Context.new(
      Groovepacker::Stores::Handlers::ShipstationRestHandler.new(store))
    context.verify_awaiting_tags(gp_ready_tag_name) 
  end

  def gp_ready_tag_name
    "GP Ready"
  end

  def gp_imported_tag_name
    "GP Imported"
  end

  def update_all_locations(tenant, user)
    result = {
      status: true,
      messages: []
    }
    import_type = 'update_locations'
    Apartment::Tenant.switch!(tenant)
    if OrderImportSummary.where(status: 'in_progress').empty?
      #delete existing order import summary
      OrderImportSummary.where(status: 'completed').delete_all
      OrderImportSummary.where(status: 'cancelled').delete_all
      #add a new import summary
      import_summary = OrderImportSummary.create(
        user: user,
        status: 'not_started',
        import_summary_type: 'update_locations'
      )

      #add import item for the store
      import_summary.import_items.create(
        store: store,
        import_type: import_type
      )
      Delayed::Job.enqueue UpdateJob.new(tenant, import_summary.import_items.first.id), :queue => 'importing_orders_'+ tenant
    else
      #import is already running. back off from importing
      result[:status] = false
      result[:messages] << "An import is already running."
    end
    result
  end

  UpdateJob = Struct.new(:tenant, :import_item_id) do
    def perform
      Apartment::Tenant.switch!(tenant)
      import_item = ImportItem.find(import_item_id)
      order_import_summary = import_item.order_import_summary
      order_import_summary.status = "in_progress"
      order_import_summary.save

      begin
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::ShipstationRestHandler.new(import_item.store, ImportItem.find(import_item_id)))
        #start importing using delayed job
        context.update_all_products
      rescue Exception => e
        import_item.message = "Import failed: " + e.message
        import_item.status = 'failed'
        import_item.save
      end
      order_import_summary.status = "completed"
      order_import_summary.save
    end
  end

  def get_active_statuses
    statuses = []
    statuses.push('awaiting_shipment') if self.shall_import_awaiting_shipment?
    statuses.push('shipped') if self.shall_import_shipped?
    statuses.push('pending_fulfillment') if self.shall_import_pending_fulfillment?
    return statuses
  end
end

