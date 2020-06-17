module ShippingEasyHelper

  def create_s3_image(item)
    image_data = Net::HTTP.get(URI.parse(item["product"]["image"]["original"]))
    # image_data = IO.read(open(item["product"]["image"]["original"]))
    file_name = "#{Time.now.strftime('%d_%b_%Y_%I__%M_%p')}_shipping_easy_#{item['sku'].downcase}"
    tenant = Apartment::Tenant.current
    GroovS3.create_image(tenant, file_name, image_data, 'public_read')
    s3_image_url = "#{ENV['S3_BASE_URL']}/#{tenant}/image/#{file_name}"
    return s3_image_url
  end

  def not_to_update(shiping_easy_order)
    not_update = (shiping_easy_order.persisted? and shiping_easy_order.status=="scanned" || (shiping_easy_order.order_items.map(&:scanned_status).include?("scanned") || shiping_easy_order.order_items.map(&:scanned_status).include?("partially_scanned")))
    @order_to_update = not_update
    not_update
  end

  def convert_time_from_gp(time)
    time_zone = GeneralSetting.last.time_zone.to_i
    (time - time_zone).strftime('%Y-%m-%d %H:%M:%S')
  end

  def update_order_import_summary
    @import_item.update_attributes(status: 'completed') if @import_item.reload.status != 'cancelled'
    @import_summary.update_attributes(status: 'completed') if OrderImportSummary.joins(:import_items).where("import_items.status = 'in_progress' OR import_items.status = 'not_started'").blank?
    @import_summary.emit_data_to_user(true)
  end

  def init_order_import_summary(user_id)
    OrderImportSummary.where("status != 'in_progress' OR status = 'completed'").destroy_all
    ImportItem.where(store_id: @credential.store.id).where("status = 'cancelled' OR status = 'completed'").destroy_all
    @import_summary = OrderImportSummary.top_summary
    @import_summary = OrderImportSummary.create(user_id: user_id, status: 'not_started', display_summary: false) unless @import_summary
    @import_item.update_attributes(order_import_summary_id: @import_summary.id, status: 'not_started')
    @import_summary.emit_data_to_user(true)
  end

  def get_quick_fix_range(import_date, order_id)
    quick_fix_range = {}
    last_imported_order = Order.find(order_id)
    store_orders = Order.where('store_id = ? AND id != ?', @credential.store.id, order_id)
    if store_orders.blank? || store_orders.where('last_modified > ?', last_imported_order.last_modified).blank?
      # Rule #1 - If there are no orders in our DB (other than the order provided to the troubleshooter, ie. the QF Order which gets automatically imported) when the QF import is run, then delete the LRO timestamp and run a regular import. - A 24 hour import range will be run rather than the usual QF range.

      # Rule #2- If the OSLMT of the QF order is newer/more recent than that of any OSLMT in DB, then run a regular import
      quick_fix_range[:start_date] = @credential.last_imported_at || (DateTime.now - 4.days)
      quick_fix_range[:end_date] = Time.zone.now
    elsif store_orders.where('last_modified < ?', last_imported_order.last_modified).blank?
      # Rule #3- If the OSLMT of the QF order is Older than any OSLMT saved in our DB , and a more recent order does exist, then start the import range 6 hours before the OSLMT of the QF order and end the range 6 hours after the OSLMT of the QF order. (12 hours with the OSLMT in the middle)
      quick_fix_range[:start_date] = last_imported_order.last_modified - 6.hours
      quick_fix_range[:end_date] = last_imported_order.last_modified + 6.hours
    else
      quick_fix_range[:start_date] = get_closest_date(order_id, import_date, '<')
      quick_fix_range[:end_date] = get_closest_date(order_id, import_date, '>')
    end
    quick_fix_range
  end

  def get_closest_date(order_id, date, comparison_operator)
    altered_date = comparison_operator == '<' ? date - 1.minute : date + 1.minute
    sort_order = comparison_operator == '<' ? 'asc' : 'desc'

    closest_date = Order.select('last_modified').where('store_id = ? AND id != ?', @credential.store.id, order_id).where("last_modified #{comparison_operator} ?", altered_date).order("last_modified #{sort_order}").last.try(:last_modified)
    return closest_date if closest_date.present?
    date
  end

  def emit_data_for_range_or_quickfix(order_count)
    @import_summary.update_attributes(status: 'in_progress')
    @import_item.update_attributes(status: 'in_progress', to_import: order_count)
    @import_summary.emit_data_to_user(true)
  end

  def ondemand_import_single_order(order)
    init_common_objects
    response = @client.get_single_order(order)
    import_single_order(response["orders"][0]) rescue nil
    remove_duplicate_order_items
    @import_item.destroy rescue nil
  end

  def init_common_objects
    handler = self.get_handler
    @credential = handler[:credential]
    @client = handler[:store_handle]
    @import_item = handler[:import_item]
    @import_item.update_attributes(updated_orders_import: 0)
    @result = self.build_result
    @statuses = get_statuses
  end

  def import_item_count(order=nil)
    unless order.blank?
      @import_item.current_order_items = order["recipients"][0]["line_items"].length
      @import_item.current_order_imported_item = 0
    else
      @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
    end
    @import_item.save
  end

  def get_statuses
    status = ["cleared"]
    status << "ready_for_shipment" if @credential.import_ready_for_shipment
    status << "shipped" if @credential.import_shipped
    status << "pending_shipment" if @credential.ready_to_ship
    status
  end

  def destroy_cleared_orders(response)
    skus = ProductKitSkus.where("option_product_id = product_id")
    skus.destroy_all
    orders_to_clear = Order.where("store_id=? and status!=? and increment_id in (?)", @credential.store_id, "scanned", response["cleared_orders_ids"])
    orders_to_clear.destroy_all
  end

  def remove_duplicate_order_items
    order_item_dup = OrderItem.where("created_at >= ?", Time.now.beginning_of_day).select(:order_id).group(:order_id, :product_id).having("count(*) > 1").count
    unless order_item_dup.empty?
      order_item_dup.each do |i|
        item = OrderItem.where(order_id: i[0][0], product_id: i[0][1])
        item.last.destroy if item.count > 1
      end
    end
  end


end
