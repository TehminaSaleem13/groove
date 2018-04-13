module ScanPackHelper

  include OrdersHelper
  include ScanPack
  
  def order_scan(input, state, id, options={})
    order_scan_object = ScanPack::OrderScanService.new(
      options[:current_user], options[:session], input, state, id
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

  def product_scan(input, state, id, box_id, options={})
    product_scan_object = ScanPack::ProductScanService.new(
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
end
