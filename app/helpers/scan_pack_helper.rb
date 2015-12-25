module ScanPackHelper

  include OrdersHelper
  include ScanPack

  def order_scan(input, state, id)
    order_scan_object = ScanPack::OrderScanService.new(
      current_user, session, input, state, id
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

  def product_scan(input, state, id, clicked=false, serial_added=false)
    product_scan_object = ScanPack::ProductScanService.new(
      [current_user, session, input, state, id]
      )
    product_scan_object.run(clicked, serial_added)
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

  def scan_recording(input, state, id)
    result = Hash.new
    result['status'] = true
    result['matched'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new
    result['data']['next_state'] = 'scanpack.rfp.recording'

    order = Order.find(id)

    if order.nil?
      result['status'] &= false
      result['error_messages'].push("Could not find order with id: "+id)
    else
      if order.status == 'awaiting'
        if input.nil?
          result['status'] &= false
          result['error_messages'].push("No tracking number is provided")
        else
          #allow tracking id to be saved without special permissions
          order.tracking_num = input
          order.set_order_to_scanned_state(current_user.username)
          result['data']['order_complete'] = true
          result['data']['next_state'] = 'scanpack.rfo'
          #update inventory when inventory warehouses is implemented.
          order.save
        end
      else
        result['status'] &= false
        result['error_messages'].push("The order is not in awaiting state. Cannot scan the tracking number")
      end
    end
    return result
  end

  def scan_verifying(input, state, id)
    result = Hash.new
    result['status'] = true
    result['matched'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new
    result['data']['next_state'] = 'scanpack.rfp.verifying'

    order = Order.find(id)

    if order.nil?
      result['status'] &= false
      result['error_messages'].push("Could not find order with id: "+id)
    else
      if order.status == 'awaiting'
        unless input.nil?
          if order.tracking_num === input || order.tracking_num === input.last(22)
            order.set_order_to_scanned_state(current_user.username)
            result['data']['order_complete'] = true
            result['data']['next_state'] = 'scanpack.rfo'
            order.addactivity("Shipping Label Verified: #{input}", current_user.username)
            order.save
          elsif input == current_user.confirmation_code
            result['matched'] = false
            order.set_order_to_scanned_state(current_user.username)
            result['data']['order_complete'] = true
            result['data']['next_state'] = 'scanpack.rfo'
            order.save
          else
            result['status'] &= false
            result['error_messages'].push("Tracking number does not match.")
            result['data']['next_state'] = 'scanpack.rfp.no_match'
          end
        end
      else
        result['status'] &= false
        result['error_messages'].push("The order is not in awaiting state. Cannot scan the tracking number")
      end
    end
    return result
  end

  def render_order_scan(input, state, id)
    result = Hash.new
    result['status'] = true
    result['matched'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new
    result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
    unless id.nil?
      order = Order.find(id)
      if state == "scanpack.rfp.no_tracking_info" && (input == current_user.confirmation_code || input == "")
        result['status'] = true
        result['matched'] = false
        order.set_order_to_scanned_state(current_user.username)
        result['data']['order_complete'] = true
        result['data']['next_state'] = 'scanpack.rfo'
        order.save
      else
        result['status'] = false
        result['matched'] = false
        result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
      end
    end
    result
  end

  def scan_again_or_render_order_scan(input, state, id)
    result = Hash.new
    result['status'] = true
    result['matched'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new
    result['data']['next_state'] = 'scanpack.rfp.no_match'
    unless id.nil?
      order = Order.find(id)
      unless order.nil?
        if state == "scanpack.rfp.no_match" && input == current_user.confirmation_code
          result['status'] = true
          result['matched'] = false
          order.set_order_to_scanned_state(current_user.username)
          result['data']['order_complete'] = true
          order.addactivity("The correct shipping label was not verified at the time of packing. Confirmation code for user #{current_user.username} was scanned", current_user.username)
          result['data']['next_state'] = 'scanpack.rfo'
          order.save
        elsif state == "scanpack.rfp.no_match" && (input === order.tracking_num || input.last(22) === order.tracking_num)
          result['status'] = true
          result['matched'] = true
          order.set_order_to_scanned_state(current_user.username)
          result['data']['order_complete'] = true
          result['data']['next_state'] = 'scanpack.rfo'
          order.save
        elsif state == "scanpack.rfp.no_match" && input == "" && GeneralSetting.all.first.strict_cc == false
          result['status'] = true
          result['matched'] = false
          order.set_order_to_scanned_state(current_user.username)
          result['data']['order_complete'] = true
          result['data']['next_state'] = 'scanpack.rfo'
        else
          result['status'] = false
          result['matched'] = false
          result['data']['next_state'] = 'scanpack.rfp.no_match'
        end
      end
    end
    result
  end

  def order_edit_conf(input, state, id)
    order_edit_conf_object = ScanPack::OrderEditConfService.new(
      [session, input, state, id]
      )
    order_edit_conf_object.run
  end

  def cos_conf(input, state, id)
    result = Hash.new
    result['status'] = true
    result['matched'] = false
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new

    if !id.nil? || !input.nil?
      #check if order status is On Hold
      single_order = Order.find(id)
      if single_order.nil?
        result['status'] &= false
        result['error_messages'].push("Could not find order with id: "+id.to_s)
      else
        result['data']['order_num'] = single_order.increment_id
        if single_order.status == "serviceissue"
          if User.where(:confirmation_code => input).length > 0
            user = User.where(:confirmation_code => input).first

            if user.can?('change_order_status')
              #set order state to awaiting scannus
              single_order.status = 'awaiting'
              single_order.save
              single_order.update_order_status
              result['matched'] = true
              #set next state
              result['data']['next_state'] = 'scanpack.rfp.default'
            else
              result['matched'] = true
              result['data']['next_state'] = 'scanpack.rfp.confirmation.cos'
              result['error_messages'].push("User with confirmation code: "+ input+ " does not have permission to change order status")
            end
          else
            result['data']['next_state'] = 'scanpack.rfp.confirmation.cos'
            result['error_messages'].push("Could not find any user with confirmation code")
          end
        else
          result['status'] &= false
          result['error_messages'].push("Only orders with status Service issue"+
                                          "can use change of status confirmation code")
        end
        result['data']['order'] = order_details_and_next_item(single_order)
      end

      #check if current user edit confirmation code is same as that entered
    else
      result['status'] &= false
      result['error_messages'].push("Please specify confirmation code and order id to change order status")
    end

    return result
  end

  def product_edit_conf(input, state, id)
    result = Hash.new
    result['status'] = true
    result['matched'] = false
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new

    if !id.nil? || !input.nil?
      #check if order status is On Hold
      single_order = Order.find(id)
      if single_order.nil?
        result['status'] &= false
        result['error_messages'].push("Could not find order with id: "+id.to_s)
      else
        if single_order.status == "onhold" && single_order.has_inactive_or_new_products
          if User.where(:confirmation_code => input).length > 0
            user = User.where(:confirmation_code => input).first
            if user.can? 'add_edit_products'
              result['matched'] = true
              result['data']['inactive_or_new_products'] = single_order.get_inactive_or_new_products
              result['data']['next_state'] = 'scanpack.rfp.product_edit'
              session[:product_edit_matched_for_current_user] = true
              session[:product_edit_matched_for_products] = []
              result['data']['inactive_or_new_products'].each do |inactive_new_product|
                session[:product_edit_matched_for_products].push(inactive_new_product.id)
              end
              session[:product_edit_matched_for_order] = single_order.id
            else
              result['data']['next_state'] = 'scanpack.rfp.confirmation.product_edit'
              result['matched'] = true
              result['error_messages'].push("User with confirmation code "+ input +
                                              " does not have permission for editing products.")
            end
          else
            result['data']['next_state'] = 'scanpack.rfo'
          end
        else
          result['status'] &= false
          result['error_messages'].push("Only orders with status On Hold and has inactive or new products "+
                                          "can use edit confirmation code.")
        end
        result['data']['order'] = order_details_and_next_item(single_order)
      end

      #check if current user edit confirmation code is same as that entered
    else
      result['status'] &= false
      result['error_messages'].push("Please specify confirmation code and order id to confirm purchase code")
    end
    return result
  end

  def order_details_and_next_item(single_order)
    single_order.reload
    data = single_order.attributes
    data['unscanned_items'] = single_order.get_unscanned_items
    data['scanned_items'] = single_order.get_scanned_items
    unless data['unscanned_items'].length == 0
      unless session[:most_recent_scanned_products].nil?
        session[:most_recent_scanned_products].reverse!.each do |scanned_product_id|
          data['unscanned_items'].each do |unscanned_item|
            if session[:parent_order_item] && session[:parent_order_item] == unscanned_item['order_item_id']
              session[:parent_order_item] = false
              if unscanned_item['product_type'] == 'individual' && !unscanned_item['child_items'].empty?
                data['next_item'] = unscanned_item['child_items'].first.clone
                break
              end
            elsif unscanned_item['product_type'] == 'single' &&
              scanned_product_id == unscanned_item['product_id'] &&
              unscanned_item['scanned_qty'] + unscanned_item['qty_remaining'] > 0
              data['next_item'] = unscanned_item.clone
              break
            elsif unscanned_item['product_type'] == 'individual'
              unscanned_item['child_items'].each do |child_item|
                if child_item['product_id'] == scanned_product_id
                  data['next_item'] = child_item.clone
                  break
                end
              end
              break if !data['next_item'].nil?
            end
          end
          break if !data['next_item'].nil?
        end
      end
      if data['next_item'].nil?
        if data['unscanned_items'].first['product_type'] == 'single'
          data['next_item'] = data['unscanned_items'].first.clone
        elsif data['unscanned_items'].first['product_type'] == 'individual'
          data['next_item'] = data['unscanned_items'].first['child_items'].first.clone unless data['unscanned_items'].first['child_items'].empty?
        end
      end
      data['next_item']['qty'] = data['next_item']['scanned_qty'] + data['next_item']['qty_remaining']
    end

    return data
  end

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
