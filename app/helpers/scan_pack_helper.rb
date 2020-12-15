module ScanPackHelper

  include OrdersHelper
  include ScanPack
  
  def order_scan(input, state, id,store_order_id,options={})
    order_scan_object = ScanPack::OrderScanService.new(
      options[:current_user], options[:session], input, state, id, store_order_id, options[:order_by_number]
    )
    order_scan_object.run
  end

  def order_scan_v2(input, state, id,store_order_id,options={}, params)
    order_scan_object = ScanPack::OrderScanServiceV2.new(
      options[:current_user], options[:session], input, state, id, store_order_id, params, options[:order_by_number]
    )
    order_scan_object.run
  end

  # def can_order_be_scanned
  #   #result = false
  #   #max_shipments = AccessRestriction.order("created_at").last.num_shipments
  #   #total_shipments = AccessRestriction.order("created_at").last.total_scanned_shipments
  #   #if total_shipments < max_shipments
  #   #  result = true
  #   #else
  #   #  result = false
  #   #end
  #   #result
  #   true
  # end

  def product_first_scan_to_wall(input)
    @result[:status] = false

    barcode = ProductBarcode.where(barcode: input).last
    product = barcode.product if barcode

    unless barcode.present? || product.present?
      @result[:notice_messages] = 'Sorry, no new orders can be found that require that item. Please check that all orders have been imported. If this is a new item that may not have the barcode saved you can search for the item by SKU in the products section and add it.'
      @result[:product_error] = true
    end

    return @result if @result[:product_error]

    # An item is scanned. The oldest single item order containing that item is found in our DB, the order is marked scanned, the post scanning call to ShippingEasy webhook is fired. Labels Print.
    order = Order.where("status = 'awaiting'").where('(SELECT COUNT(*) FROM order_items WHERE order_items.order_id = orders.id) = 1').joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id).group(:id).having("SUM(order_items.qty) = 1").order('order_placed_time ASC').readonly(false).first
    if order.present?
      order_item = order.order_items.where(product_id: product.id).first
      order.update_attributes(last_suggested_at: DateTime.now)
      order_item.process_item(nil, @current_user.username, 1, nil)
      order.addactivity("Product with barcode: #{input} and sku: #{order_item.product.primary_sku} scanned", @current_user.name)
      order.set_order_to_scanned_state(@current_user.username)
      @result[:single_item_order] = true
      @result[:status] = true
      @result[:product] = product
      @result[:barcode] = product.primary_sku
      @result[:order] = order
      @result[:store_type] = order.store.store_type
      @result[:single_item_order_message] = @scanpack_setting.single_item_order_complete_msg
      @result[:single_item_order_message_time] = @scanpack_setting.single_item_order_complete_msg_time
      @result[:popup_shipping_label] = order.store.shipping_easy_credential.popup_shipping_label rescue nil
      ScanPack::ScanBarcodeService.new(current_user, session, params).generate_order_barcode_slip(order) if @scanpack_setting.post_scanning_option == 'Barcode' && !@result[:popup_shipping_label]
      return @result
    end

    # If no single item orders are found with that item then all orders that have been assigned to a tote are searched to see if the item is required. If any toted orders require that item a check is done to see if that item completes any of the orders.
    orders = Order.includes([:tote]).where("orders.id IN (?) AND status = 'awaiting'", Tote.all.map(&:order_id).compact).joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id).reject { |o| o.id.in? Tote.where(pending_order: true).pluck(:order_id).compact }
    if orders.any?
      can_complete_orders = orders.select { |o| o.get_unscanned_items.count == 1 && o.get_unscanned_items[0]['qty_remaining'] == 1}
      if can_complete_orders.any?
        # If so, the user is prompted to scan the tote number that was assigned to the completed order. The user is notified that the order is Done. The order is marked Scanned and the webhook will be called to print the labels.
        @result[:scan_tote_to_complete] = true
        tote = can_complete_orders.map(&:tote).sort_by(&:number).first
        order = tote.order
        order_item = OrderItem.find(order.get_unscanned_items.first['order_item_id'])
        @result[:tote] = tote
        @result[:tote_identifier] = @scanpack_setting.tote_identifier
        @result[:product] = product
        @result[:barcode] = product.primary_sku
        @result[:order] = order
        @result[:order_item] = order_item
        @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
        @result[:order_items_unscanned] = []
        @result[:order_items_partial_scanned] = []
        current_item = order.get_unscanned_items.select { |item| item['order_item_id'] == order_item.id }.first
        tote.update_attributes(order_id: order.id, pending_order: true)
        current_item['scanned_qty'] = current_item['scanned_qty'] + 1
        current_item['qty_remaining'] = current_item['qty_remaining'] - 1
        @result[:barcode_input] = input
        order.addactivity("Barcode #{input} was scanned for SKU #{@result[:barcode]} setting the order PENDING in #{@result[:tote_identifier]} #{tote.name}.", @current_user.name)
        @result[:order_items_scanned] << current_item
        @result[:status] = true
      else
        # If the item is required in a toted order but does not complete the order then the item will be assigned to the lowest-numbered tote requiring the item and that tote number will be prompted for scanning. After it is scanned GP will prompt the user for the next product scan.
        tote = orders.map(&:tote).sort_by(&:number).first
        @result[:put_in_tote] = true
        order = tote.order
        order_item = order.order_items.where(product_id: product.id).first
        @result[:tote] = tote
        @result[:tote_identifier] = @scanpack_setting.tote_identifier
        @result[:product] = product
        @result[:barcode] = product.primary_sku
        @result[:order] = order
        @result[:order_item] = order_item
        @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
        @result[:order_items_unscanned] = order.get_unscanned_items.select { |item| item['scanned_qty'] == 0 && item['order_item_id'] != order_item.id }
        @result[:order_items_partial_scanned] = order.get_unscanned_items.select { |item| item['scanned_qty'] != 0 && item['order_item_id'] != order_item.id }
        current_item = order.get_unscanned_items.select { |item| item['order_item_id'] == order_item.id }.first
        tote.update_attributes(order_id: order.id, pending_order: true)
        current_item['scanned_qty'] = current_item['scanned_qty'] + 1
        current_item['qty_remaining'] = current_item['qty_remaining'] - 1
        current_item['qty_remaining'] > 0 ? @result[:order_items_partial_scanned] << current_item : @result[:order_items_scanned] << current_item
        order.addactivity("Barcode #{input} was scanned for SKU #{@result[:barcode]} setting the order PENDING in #{@result[:tote_identifier]} #{tote.name}.", @current_user.name)
        @result[:barcode_input] = input
        @result[:status] = true
      end
      return @result
    end

    # If the item is not required in any toted orders, the oldest multi-item order requiring the item is found in our DB.
    order = Order.where("status = 'awaiting'").joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id).order('order_placed_time ASC').reject { |o| o.id.in? Tote.where(pending_order: true).pluck(:order_id).compact }.first
    available_tote = Tote.where(order_id: order.id, pending_order: false).first if order.present?
    available_tote = Tote.order('number ASC').where(order_id: nil, pending_order: false).first unless available_tote.try(:present?)
    tote_set = ToteSet.last || ToteSet.create(name: 'T')
    available_tote = tote_set.totes.create(name: "T-#{Tote.all.count + 1}", number: Tote.all.count + 1) if Tote.all.count < tote_set.max_totes && !available_tote

    if order.present? && available_tote.present?
      # The lowest available open tote number is displayed and we wait for the user to scan the number. Once scanned, the order is assigned to that tote and we record that the item is scanned into that tote.
      order_item = order.order_items.where(product_id: product.id).first
      @result[:assigned_to_tote] = true
      @result[:tote] = available_tote
      @result[:tote_identifier] = @scanpack_setting.tote_identifier
      @result[:product] = product
      @result[:barcode] = product.primary_sku
      @result[:order] = order
      @result[:order_item] = order_item
      @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
      @result[:order_items_unscanned] = order.get_unscanned_items.select { |item| item['scanned_qty'] == 0 && item['order_item_id'] != order_item.id }
      @result[:order_items_partial_scanned] = order.get_unscanned_items.select { |item| item['scanned_qty'] != 0 && item['order_item_id'] != order_item.id }
      current_item = order.get_unscanned_items.select { |item| item['order_item_id'] == order_item.id }.first
      current_item['scanned_qty'] = current_item['scanned_qty'] + 1
      current_item['qty_remaining'] = current_item['qty_remaining'] - 1
      current_item['qty_remaining'] > 0 ? @result[:order_items_partial_scanned] << current_item : @result[:order_items_scanned] << current_item
      @result[:barcode_input] = input
      order.addactivity("Barcode #{input} was scanned for SKU #{@result[:barcode]} setting the order PENDING in #{@result[:tote_identifier]} #{available_tote.name}.", @current_user.name)
      @result[:status] = true
      available_tote.update_attributes(order_id: order.id, pending_order: true)
      return @result
    end

    @result[:no_order] = true

    orders = Order.where(status: 'onhold').joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id)
    if orders.any?
      #If there are no multi-item orders with the Awaiting Status requiring the item then Action Required orders will be checked. If one is found we will give the following notification
      # “The remaining orders that contain this item are not ready to be scanned. This is usually because one or more items in the order do not have a barcode assigned yet. You can find all products that require barcodes in the New Products List”
      @result[:notice_messages] = 'The remaining orders that contain this item are not ready to be scanned. This is usually because one or more items in the order do not have a barcode assigned yet. You can find all products that require barcodes in the New Products List'
    else
      # If there are no open orders requiring the item that was scanned we will alert the user: Sorry, no orders require that item.
      @result[:notice_messages] = 'Sorry, no orders can be found that require that item. Please check that all orders have been imported. If this is a new item that may not have the barcode saved you can search for the item by SKU in the products section and add it.'
    end

    @result
  end

  def product_scan(input, state, id, box_id, options={})
    product_scan_object = ScanPack::ProductScanService.new(
      [
        options[:current_user], options[:session],
        input, state, id, box_id, options[:typein_count] || 1
      ]
    )
    product_scan_object.run(options[:clicked], options[:serial_added])
  end

  def product_scan_v2(input, state, id, box_id, options={})
    product_scan_object = ScanPack::ProductScanServiceV2.new(
      [
        options[:current_user], options[:session],
        input, state, id, box_id, options[:typein_count] || 1
      ]
    )
    product_scan_object.run(options[:clicked], options[:serial_added])
  end

  # def process_scan(clicked, order_item, serial_added, result)
  #   unless order_item.nil?
  #     if order_item.product.record_serial
  #       if serial_added
  #         order_item.process_item(clicked, current_user.username)
  #         (session[:most_recent_scanned_products] ||= []) << order_item.product_id
  #         session[:parent_order_item] = false
  #         if order_item.product.is_kit == 1
  #           session[:parent_order_item] = order_item.id
  #         end
  #       else
  #         result['data']['serial']['ask'] = true
  #         result['data']['serial']['product_id'] = order_item.product_id
  #       end
  #     else
  #       order_item.process_item(clicked, current_user.username)
  #       (session[:most_recent_scanned_products] ||= []) << order_item.product_id
  #       session[:parent_order_item] = false
  #       if order_item.product.is_kit == 1
  #         session[:parent_order_item] = order_item.id
  #       end
  #     end
  #   end
  #   result
  # end

  # def calculate_lot_number(scanpack_settings, input)
  #   if scanpack_settings.escape_string_enabled && !input.index(scanpack_settings.escape_string).nil?
  #     return input.slice((input.index(scanpack_settings.escape_string)+scanpack_settings.escape_string.length)..(input.length-1))
  #   end
  # end

  def scan_recording(input, state, id, options={})
    scan_recording_object = ScanPack::ScanRecordingService.new(
      [options[:current_user], input, id]
      )
    scan_recording_object.run
  end

  def scan_verifying(input, state, id, options={})
    scan_verifying_object = ScanPack::ScanVerifyingService.new(
      [options[:current_user], input, id]
      )
    scan_verifying_object.run
  end

  def render_order_scan(input, state, id, options={})
    render_order_scan_object = ScanPack::RenderOrderScanService.new(
      [options[:current_user], input, state, id]
      )
    render_order_scan_object.run
  end

  def scan_again_or_render_order_scan(input, state, id, options={})
    scan_again_or_render_order_scan_object = ScanPack::ScanAginOrRenderOrderScanService.new(
      [options[:current_user], input, state, id]
      )
    scan_again_or_render_order_scan_object.run
  end

  def order_edit_conf(input, state, id, options={})
    order_edit_conf_object = ScanPack::OrderEditConfService.new(
      [options[:session], input, state, id]
      )
    order_edit_conf_object.run('order_edit_conf')
  end

  def cos_conf(input, state, id, options={})
    cos_conf_object = ScanPack::CosConfService.new(
      [options[:session], input, state, id]
      )
    cos_conf_object.run('cos_conf')
  end

  def product_edit_conf(input, state, id, options={})
    product_edit_conf_object = ScanPack::ProductEditConfService.new(
      [options[:session], input, state, id]
      )
    product_edit_conf_object.run('product_edit_conf')
  end

  # def order_details_and_next_item(single_order)
  #   single_order.reload
  #   data = single_order.attributes
  #   data['unscanned_items'] = single_order.get_unscanned_items
  #   data['scanned_items'] = single_order.get_scanned_items
  #   unless data['unscanned_items'].length == 0
  #     unless session[:most_recent_scanned_products].nil?
  #       session[:most_recent_scanned_products].reverse!.each do |scanned_product_id|
  #         data['unscanned_items'].each do |unscanned_item|
  #           if session[:parent_order_item] && session[:parent_order_item] == unscanned_item['order_item_id']
  #             session[:parent_order_item] = false
  #             if unscanned_item['product_type'] == 'individual' && !unscanned_item['child_items'].empty?
  #               data['next_item'] = unscanned_item['child_items'].first.clone
  #               break
  #             end
  #           elsif unscanned_item['product_type'] == 'single' &&
  #             scanned_product_id == unscanned_item['product_id'] &&
  #             unscanned_item['scanned_qty'] + unscanned_item['qty_remaining'] > 0
  #             data['next_item'] = unscanned_item.clone
  #             break
  #           elsif unscanned_item['product_type'] == 'individual'
  #             unscanned_item['child_items'].each do |child_item|
  #               if child_item['product_id'] == scanned_product_id
  #                 data['next_item'] = child_item.clone
  #                 break
  #               end
  #             end
  #             break if !data['next_item'].nil?
  #           end
  #         end
  #         break if !data['next_item'].nil?
  #       end
  #     end
  #     if data['next_item'].nil?
  #       if data['unscanned_items'].first['product_type'] == 'single'
  #         data['next_item'] = data['unscanned_items'].first.clone
  #       elsif data['unscanned_items'].first['product_type'] == 'individual'
  #         data['next_item'] = data['unscanned_items'].first['child_items'].first.clone unless data['unscanned_items'].first['child_items'].empty?
  #       end
  #     end
  #     data['next_item']['qty'] = data['next_item']['scanned_qty'] + data['next_item']['qty_remaining']
  #   end

  #   return data
  # end

  def barcode_found_or_special_code(barcode)
    confirmation_code = User.find_by_confirmation_code(barcode)
    unless confirmation_code.nil?
      return true
    end
    if ScanPackSetting.is_action_code(barcode)
      return true
    end
    barcode_data = ProductBarcode.find_by_barcode(barcode)
    return !barcode_data.nil?
  end

  # def generate_packing_slip(order)
  #   result = Hash.new
  #   result['status'] = false
  #   if GeneralSetting.get_packing_slip_size == '4 x 6'
  #     @page_height = '6'
  #     @page_width = '4'
  #   else
  #     @page_height = '11'
  #     @page_width = '8.5'
  #   end
  #   @size = GeneralSetting.get_packing_slip_size
  #   @orientation = GeneralSetting.get_packing_slip_orientation
  #   # Earlier this was @result so it messed up with @result from the method.
  #   # Changed it to @slip_data_hash
  #   @slip_data_hash = Hash.new
  #   @slip_data_hash['data'] = Hash.new
  #   @slip_data_hash['data']['packing_slip_file_paths'] = []

  #   if @orientation == 'landscape'
  #     @page_height = @page_height.to_f/2
  #     @page_height = @page_height.to_s
  #   end
  #   @header = ''

  #   @file_name = Apartment::Tenant.current+Time.now.strftime('%d_%b_%Y_%I__%M_%p')
  #   @orders = []

  #   single_order = Order.find(order.id)
  #   unless single_order.nil?
  #     @orders.push({id: single_order.id, increment_id: single_order.increment_id})
  #   end
  #   unless @orders.empty?
  #     GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
  #     @generate_barcode = GenerateBarcode.new
  #     @generate_barcode.user_id = current_user.id
  #     @generate_barcode.current_order_position = 0
  #     @generate_barcode.total_orders = @orders.length
  #     @generate_barcode.next_order_increment_id = @orders.first[:increment_id] unless @orders.first.nil?
  #     @generate_barcode.status = 'scheduled'

  #     @generate_barcode.save
  #     delayed_job = GeneratePackingSlipPdf.delay(:run_at => 1.seconds.from_now).generate_packing_slip_pdf(@orders, Apartment::Tenant.current, @slip_data_hash, @page_height, @page_width, @orientation, @file_name, @size, @header, @generate_barcode.id)
  #     @generate_barcode.delayed_job_id = delayed_job.id
  #     @generate_barcode.save
  #     result['status'] = true
  #   end
  # end

  # def generate_order_barcode_slip(order)
  #   require 'wicked_pdf'
  #   GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
  #   @generate_barcode = GenerateBarcode.new
  #   @generate_barcode.user_id = current_user.id
  #   @generate_barcode.current_order_position = 0
  #   @generate_barcode.total_orders = 1
  #   @generate_barcode.current_increment_id = order.increment_id
  #   @generate_barcode.next_order_increment_id = nil
  #   @generate_barcode.status = 'in_progress'

  #   @generate_barcode.save
  #   file_name_order = Digest::MD5.hexdigest(order.increment_id)
  #   reader_file_path = Rails.root.join('public', 'pdfs', "#{Apartment::Tenant.current}.#{file_name_order}.pdf")
  #   ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
  #   av = ActionView::Base.new()
  #   av.view_paths = ActionController::Base.view_paths
  #   av.class_eval do
  #     include Rails.application.routes.url_helpers
  #     include ApplicationHelper
  #     include ProductsHelper
  #   end
  #   @order = order
  #   tenant_name = Apartment::Tenant.current
  #   file_name = tenant_name + Time.now.strftime('%d_%b_%Y_%I__%M_%p')
  #   pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}_order_number.pdf")
  #   pdf_html = av.render :template => 'orders/generate_order_barcode_slip.html.erb', :layout => nil, :locals => {:@order => @order}
  #   doc_pdf = WickedPdf.new.pdf_from_string(
  #     pdf_html,
  #     :inline => true,
  #     :save_only => false,
  #     :page_height => '1in',
  #     :page_width => '3in',
  #     :margin => {:top => '0',
  #                 :bottom => '0',
  #                 :left => '0',
  #                 :right => '0'}
  #   )
  #   File.open(reader_file_path, 'wb') do |file|
  #     file << doc_pdf
  #   end
  #   base_file_name = File.basename(pdf_path)
  #   pdf_file = File.open(reader_file_path)
  #   GroovS3.create_pdf(tenant_name, base_file_name, pdf_file.read)
  #   pdf_file.close
  #   @generate_barcode.url = ENV['S3_BASE_URL']+'/'+tenant_name+'/pdf/'+base_file_name
  #   @generate_barcode.status = 'completed'
  #   @generate_barcode.save
  # end

  # # Remove those order_items that are skippable when the scanned barcode
  # # is SKIP entered as the barcode.
  # def remove_skippable_product item
  #   order_item = OrderItem.find(item['order_item_id'])
  #   order = order_item.order
  #   order.order_items.delete(order_item)
  #   order.save
  # end

  def add_on_demand_import_to_delay(order_no_input, job, store)
    if Delayed::Job.where('queue = ? OR queue LIKE ? OR queue = ? AND id != ?', "importing_orders_#{Apartment::Tenant.current}", "%on_demand_scan_#{Apartment::Tenant.current}%", "start_range_import_#{Apartment::Tenant.current}", job.try(:id).to_i).any?
      @result['notice_messages'] = 'The order you have scanned is not available in GroovePacker. An import is already in progress so we are not able to request it directly. Please try scanning it again after the import completes.'
    else
      order_importer = Groovepacker::Stores::Importers::OrdersImporter.new(nil)
      order_importer.delay(:run_at => 1.seconds.from_now, :queue => "on_demand_scan_#{Apartment::Tenant.current}_#{order_no_input}", priority: 95).search_and_import_single_order(tenant: Apartment::Tenant.current, order_no: order_no_input, user_id: @current_user.id)
      #order_importer.search_and_import_single_order(tenant: current_tenant, order_no: order_no_input)
      if store.present? && store.on_demand_import == true
        @result['notice_messages'] = "It does not look like that order has been imported into GroovePacker. We'll attempt to import it in the background and you can continue scanning other orders while it imports."
      elsif store.present? && store.on_demand_import_v2 == true
        @result["on_demand"] = true
      end
    end
  end
end
