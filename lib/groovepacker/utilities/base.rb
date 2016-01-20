class Base
  
  def init_import(tenant)
    Apartment::Tenant.switch(tenant)
  end
  
  def get_handler(store_type, store, import_item)
    case store_type
    when 'Amazon'
      handler = Groovepacker::Stores::Handlers::AmazonHandler.new(store, import_item)
    when 'Ebay'
      handler = Groovepacker::Stores::Handlers::EbayHandler.new(store, import_item)
    when 'Magento'
      handler = Groovepacker::Stores::Handlers::MagentoHandler.new(store, import_item)
    when 'Magento API 2'
      handler = Groovepacker::Stores::Handlers::MagentoRestHandler.new(store, import_item)
    when 'Shipstation'
      handler = Groovepacker::Stores::Handlers::ShipstationHandler.new(store, import_item)
    when 'Shipstation API 2'
      handler = Groovepacker::Stores::Handlers::ShipstationRestHandler.new(store, import_item)
    when 'ShippingEasy'
      handler = Groovepacker::Stores::Handlers::ShippingEasyHandler.new(store, import_item)
    when 'Shopify'
      handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(store, import_item)
    when 'BigCommerce'
      handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(store, import_item)
    end
    return handler
  end

  def common_data_attributes
    return ["fix_width", "fixed_width", "sep", "delimiter", "rows", "map", "map", "import_action",
            "contains_unique_order_items", "generate_barcode_from_sku", "use_sku_as_product_name",
            "order_placed_at", "order_date_time_format", "day_month_sequence"
          ]
  end

  def get_order_import_summary
    return nil unless OrderImportSummary.where(status: 'in_progress').empty?
    return nil if order_import_summaries.empty?
    @order_import_summary = order_import_summaries.first
    @order_import_summary.update_attributes(status: 'in_progress')
    @order_import_summary.reload
  end

  def order_import_summaries
    @order_import_summaries ||= OrderImportSummary.where(status: 'not_started').order("updated_at DESC")
  end

  def delete_existing_order_import_summaries
    OrderImportSummary.where("status in (?)", ['completed', 'cancelled']).delete_all
  end

  def new_import_item(store_id, message = nil, status = nil)
    import_item = ImportItem.new
    import_item.store_id = store_id
    import_item.order_import_summary_id = @order_import_summary.id
    import_item.status = status
    import_item.message = message
    import_item.save!
  end

  ImportJob = Struct.new(:tenant, :order_import_summary_id) do
    def perform
      Apartment::Tenant.switch(tenant)
      ois = OrderImportSummary.find_by_id(order_import_summary_id)
      ois.update_attributes(status: 'in_progress')

      ois.import_items.each {|import_item| ImportOrders.new.import_orders_with_import_item(import_item, tenant) }
      ois.reload
      ois.update_attributes(status: 'completed') unless ois.status == 'cancelled'
    end
  end

end
