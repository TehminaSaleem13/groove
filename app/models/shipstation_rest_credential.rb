class ShipstationRestCredential < ActiveRecord::Base
  attr_accessible :api_key, :api_secret, :store_id, :shall_import_, :regular_import_range, :gen_barcode_from_sku
  validates_presence_of :api_key, :api_secret, :regular_import_range

  belongs_to :store

  def verify_tags
    context = Groovepacker::Store::Context.new(
      Groovepacker::Store::Handlers::ShipstationRestHandler.new(store))
    context.verify_tags([gp_ready_tag_name, gp_imported_tag_name])
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
    Apartment::Tenant.switch(tenant)
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
      Apartment::Tenant.switch(tenant)
      import_item = ImportItem.find(import_item_id)
      order_import_summary = import_item.order_import_summary
      order_import_summary.status = "in_progress"
      order_import_summary.save

      begin
        context = Groovepacker::Store::Context.new(
          Groovepacker::Store::Handlers::ShipstationRestHandler.new(import_item.store, ImportItem.find(import_item_id)))
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
end

