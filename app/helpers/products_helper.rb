module ProductsHelper

  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

  require 'mws-connect'
  # requires a product is created with appropriate seller sku
  def import_amazon_product_details(store_id, product_sku, product_id)
    ProductsService::AmazonImport.call(store_id, product_sku, product_id)
  end

  def updatelist(product, var, value, current_user = nil, permit_same_barcode = nil)
    ProductsService::UpdateList.call(product, var, value, current_user, permit_same_barcode)
  end

  # gets called from orders helper
  def import_ebay_product(itemID, sku, ebay, credential)
    ProductsService::EbayImport.call(itemID, sku, ebay, credential)
  end

  def generate_barcode(barcode_string)
    barcode = Barby::Code128B.new(barcode_string)
    outputter = Barby::PngOutputter.new(barcode)
    outputter.margin = 0
    blob = outputter.to_png # Raw PNG data
    image_name = Digest::MD5.hexdigest(barcode_string)
    File.open("#{Rails.root}/public/images/#{image_name}.png",
              'w') do |f|
      f.write blob
    end
    image_name
  end

  def list_selected_products(params, include_association = true)
    ProductsService::ListSelectedProducts.call(params, include_association)
  end

  def do_getproducts(params)
    ProductsService::FindProducts.call(params)
  end

  def do_get_report_products(params)
    ProductsService::FindProducts.new(params).get_report_products
  end

  def do_search(params, results_only = true)
    ProductsService::SearchProducts.call(params, results_only)
  end

  def self.products_csv(products, csv, bulk_actions_id = nil, bulk_csv = nil)
    ProductsService::GenerateCSV.call(products, csv, bulk_actions_id, bulk_csv)
  end

  def self.kit_csv(products, csv, bulk_actions_id = nil, bulk_csv = nil)
    ProductsService::GenerateKitCSV.call(products, csv, bulk_actions_id, bulk_csv)
  end

  def add_inventory_report_products(params)
    product_report = ProductInventoryReport.where(id: params[:data][:report_id]).first
    if product_report
      if params[:data][:select_toggle]
        search_params = { search: params[:data][:search], sort: '', order: 'DESC', is_kit: '-1', offset: 0, limit: Product.count }
        product_ids = params[:data][:search].present? ? do_search(search_params).map(&:id) : Product.all.map(&:id)
      else
        product_ids = params[:data][:selected]
      end
      product_report.product_ids = (product_report.product_ids << product_ids).flatten.uniq
    end
    @result['status'] = true
    return @result
  end

  def remove_report_products(params)
    product_report = ProductInventoryReport.where(id: params[:data][:report_id]).first
    if product_report
      if params[:data][:select_toggle]
        search_params = { search: params[:data][:search], sort: '', order: 'DESC', is_kit: '-1', offset: 0, limit: Product.count }
        if params[:data][:search].present?
          product_ids = do_search(search_params).map(&:id)
          product_report.product_ids = product_report.product_ids - product_ids
        else
          product_report.product_ids = []
        end
      else
        product_report.product_ids = product_report.product_ids - params[:data][:selected]
      end
    end
    @result['status'] = true
    return @result
  end

  def make_product_intangible(product)
    scan_pack_settings = ScanPackSetting.all.first
    return unless scan_pack_settings.intangible_setting_enabled &&
                  scan_pack_settings.intangible_string.present?
    intangible_strings = scan_pack_settings.intangible_string.strip.split(',')
    intangible_strings.each do |string|
      next unless (product.name.downcase.include?(string.downcase)) ||
                  (product.primary_sku.try(:downcase).try(:include?, string.downcase))
      product = Product.find(product.id, :readonly => false)
      product.is_intangible = true
      product.save 
      break
    end
  end

  def replace_product(product, sku)
    scan_pack_settings = ScanPackSetting.all.first
    intangible_strings = scan_pack_settings.intangible_string.downcase.strip.split(',')
    coupan_product = nil
    intangible_strings.each do |string|
      if product.downcase.include?(string) || sku.downcase.include?(string)
        coupan_product = Product.joins(:product_skus).where("product_skus.sku =  ?", "GP Coupon").readonly(false).last
        if coupan_product.nil?
          coupan_product  =  Product.new
          coupan_product.name = "GP Coupon"
          coupan_product.store_id = 1
        end   
        coupan_product.is_intangible =  true
        coupan_product.status=  "active"
        coupan_product.save
        coupan_product.product_skus.create(sku: "GP Coupon") if coupan_product.present?
        break
      end  
    end
    coupan_product
  end

  def check_for_replace_product
    scan_pack_settings = ScanPackSetting.all.first
    scan_pack_settings.intangible_setting_enabled && scan_pack_settings.intangible_string.present? && scan_pack_settings.replace_gp_code
  end

  def get_weight_format(weight_format)
    if weight_format.present?
      return weight_format
    else
      return GeneralSetting.get_product_weight_format
    end
  end

  def get_barcode_slip_template
    g_setting = GeneralSetting.last
    g_setting.show_primary_bin_loc_in_barcodeslip ? "generate_barcode_slip_with_binloc.html.erb" 
                                                  : 'generate_barcode_slip.html.erb'
  end

  def generate_report(ids)
    tenant = Apartment::Tenant.current
    InventoryReportMailer.delay.manual_inventory_report(ids, tenant)
    # InventoryReportMailer.manual_inventory_report(ids).deliver
  end

  def update_inv_record(data, params)
    selected_ids = data["selected"] || data["selected_id"]

    if data["select_toggle"]
      search_params = { search: data[:search], sort: '', order: 'DESC', is_kit: '-1', offset: 0, limit: Product.count }
      product_ids = data[:search].present? ? do_search(search_params).map(&:id) : Product.all.map(&:id)
    else
      product_ids = selected_ids
    end

    id = data["report_id"] || params["data"]["id"]
    report = id.present? ? ProductInventoryReport.find(id) : ProductInventoryReport.new
    report.scheduled = data["scheduled"] if id.present?
    report.type = data["type"] if id.present?
    report.product_ids = product_ids unless report.persisted?
    report_name = data["report_name"] || data["name"]
    report.name = report_name.present? ? report_name : "Default Report"
    report.save
    @result["status"] = true
    @result
  end

  def fetch_order_response_from_ss(start_date, end_date, type)
    response = {"orders" => []}
    statuses.each do |status|
      status_response = @client.get_range_import_orders(start_date, end_date, type, @credential.order_import_range_days, status)
      response = get_orders_from_union(response, status_response)
    end
    response
  end

  def barcode_labels_generate(tenant, params, bulk_actions_id, username)
    Apartment::Tenant.switch(tenant)
    result = {"messages"=>[], "status"=>true}
    bulk_action = GrooveBulkActions.find(bulk_actions_id)
    bulk_action_type = bulk_action.activity == 'order_product_barcode_label' ? 'order_items' : 'products'
    if bulk_action.activity == 'order_product_barcode_label'
      order_ids = params['ids'].split(",").reject { |c| c.empty? } rescue nil
      all_items = params[:ids] == "all" ? (params[:status] == "all" ? Order.includes(:order_items).map(&:order_items).flatten : Order.where(status: params[:status]).includes(:order_items).map(&:order_items).flatten) : Order.where("id in (?)", order_ids).includes(:order_items).map(&:order_items).flatten
    else
      all_items = list_selected_products(params)
    end
    process_barcode_generation(bulk_action, all_items, username, bulk_action_type, result)
  end

  def process_barcode_generation(bulk_action, all_items, username, bulk_action_type, result)
    begin
      bulk_action.update_attributes(:status => 'in_progress', total: all_items.count)
      (all_items||[]).in_groups_of(500, false) do |item_batch|
        bulk_action.reload
        if bulk_action.cancel?
          bulk_action.update_attributes(:status => 'cancelled')
          return true
        end
        last_batch = (all_items||[]).in_groups_of(500, false).last == item_batch
        ScanPack::Base.new.bulk_barcodes_with_delay(item_batch, username, bulk_action_type, last_batch)
        bulk_action.update_attributes(:completed => all_items.find_index(item_batch.last) + 1)
      end
      bulk_action.update_attributes(:status => result['status'] ? 'completed' : 'failed', :messages => result['messages'], :current => '') unless bulk_action.cancel?
    rescue Exception => e
      bulk_action.update_attributes(:status => 'failed', :messages => e, :current => '')
    end
  end

  def search_order_in_db(order)
    if @credential.allow_duplicate_order == true
      Order.find_by_store_id_and_increment_id_and_store_order_id(@credential.store_id, order["orderNumber"], order["orderId"])
    else
      Order.find_by_store_id_and_increment_id(@credential.store_id, order["orderNumber"])
    end
  end

  def se_duplicate_orders(order)
    return [] unless order.store.store_type == 'ShippingEasy'

    duplicate_orders = []

    se_shipments = Order.where('orders.prime_order_id = ? AND orders.store_order_id = ? AND orders.id != ?', order.prime_order_id, order.store_order_id, order.id).order(:increment_id)
    return duplicate_orders if se_shipments.blank?

    se_shipments.each do |shipment|
      if shipment.status == 'scanned'
        shipment_status = 'Scanned'
      else
        shipment_status = shipment.scanning_count[:scanned].to_i > 0 ? 'Partial Scanned' : 'Unscanned'
      end
      duplicate_orders << [shipment.id, shipment.increment_id, shipment_status, shipment.order_placed_time.try(:strftime, '%A, %d %b %Y %l:%M %p'), shipment.scanned_on.try(:strftime, '%A, %d %b %Y %l:%M %p'), shipment.tracking_num]
    end
    duplicate_orders
  end

  def se_old_shipments(order)
    old_shipments = []
    shipments = Order.where(store_order_id: order.split_from_order_id.split(',').map(&:to_i)) if order.split_from_order_id.present?
    shipments = Order.where('orders.prime_order_id = ?', order.prime_order_id) if Order.where(prime_order_id: order.prime_order_id).count > 1 && Order.where(store_order_id: order.prime_order_id, prime_order_id: order.prime_order_id).any? && shipments.blank?
    return old_shipments if shipments.blank?
    shipments.each do |shipment|
      if shipment.status == 'scanned'
        shipment_status = 'Scanned'
      else
        shipment_status = shipment.scanning_count[:scanned].to_i > 0 ? 'Partial Scanned' : 'Unscanned'
      end
      old_shipments << [shipment.id, shipment.increment_id, shipment_status]
    end
    old_shipments
  end

  def se_all_shipments(order)
    all_shipments = { shipments: [] }
    shipments = Order.where('orders.prime_order_id = ? AND orders.store_order_id != ? AND orders.status != ?', order.prime_order_id, order.store_order_id, 'scanned') if Order.where(prime_order_id: order.prime_order_id).count > 1
    return all_shipments if shipments.blank?
    order_split_inc = order.increment_id.split(" (S")
    order_shipment_no = order_split_inc.last.chop.to_i rescue 1
    order_inc_id = order_split_inc[0..(order_split_inc.length-2)].join rescue order.increment_id
    all_shipments[:present] = true
    all_shipments[:order_shipment_no] = order_shipment_no
    all_shipments[:order_shipment_count] = shipments.count + 1
    all_shipments[:order_inc_id] = order_inc_id
    shipments.each do |shipment|
      split_inc = shipment.increment_id.split(" (S")
      shipment_no = split_inc.last.chop.to_i rescue 1
      inc_id = split_inc[0..(split_inc.length-2)].join rescue shipment.increment_id
      items_count = shipment.get_items_count
      all_shipments[:shipments] << [shipment_no, inc_id, shipment.increment_id, items_count, shipment.id]
    end
    all_shipments
  end
end
