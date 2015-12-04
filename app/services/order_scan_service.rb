class OrderScanService
  def initialize(current_user, session, input, state, id)
    @current_user = current_user
    @input = input
    @state = state
    @id = id
    @result = {
      "status" => true,
      "matched" => true,
      "error_messages" => [],
      "success_messages" => [],
      "notice_messages" => [],
      "data" => {
        "next_state" => "scanpack.rfo"
        }
    }
    @orders = []
    @scanpack_settings = ScanPackSetting.all.first
    @session = session.merge({
      most_recent_scanned_products: [],
      parent_order_item: false
    })
  end

  def run
    check_validity? ? order_scan : (return @result)
    @result
  end

  def check_validity?
    validity = @input && @input != ""
    unless validity
      @result['status'] &= false
      @result['error_messages'].push("Please specify a barcode to scan the order")
    end
    validity
  end

  def order_scan
    @orders = Order.where(['increment_id = ? or non_hyphen_increment_id =?', @input, @input])
    if @orders.length == 0 && @scanpack_settings.scan_by_tracking_number
      @orders = Order.where('tracking_num = ?', @input)
      if @orders.length == 0
        @orders = Order.where('? LIKE CONCAT("%",tracking_num,"%") ', @input)
      end
    end
    single_order = nil
    single_order_result = Hash.new
    single_order_result['matched_orders'] = []

    if @orders.length == 1
      single_order = @orders.first
    else
      @orders.each do |matched_single|
        if single_order.nil?
          single_order = matched_single
        elsif matched_single.status == 'awaiting' &&
          (single_order.status != 'awaiting' || single_order.order_placed_time < matched_single.order_placed_time)
          single_order = matched_single
        elsif matched_single.status == 'onhold' && single_order.status != 'awaiting' &&
          (single_order.status != 'onhold' || single_order.order_placed_time < matched_single.order_placed_time)
          single_order = matched_single
        elsif matched_single.status == 'serviceissue' && single_order.status != 'awaiting' && single_order.status != 'onhold' &&
          (single_order.status != 'serviceissue' || single_order.order_placed_time < matched_single.order_placed_time)
          single_order = matched_single
        end
        unless ['scanned', 'cancelled'].include?(matched_single.status)
          single_order_result['matched_orders'].push(matched_single)
        end
      end
    end

    if single_order.nil?
      if @scanpack_settings.scan_by_tracking_number
        @result['notice_messages'].push('Order with tracking number '+
                                         @input +' cannot be found. It may not have been imported yet')
      else
        @result['notice_messages'].push('Order with number '+
                                         @input +' cannot be found. It may not have been imported yet')
      end
    else
      single_order_result['status'] = single_order.status
      single_order_result['order_num'] = single_order.increment_id

      #can order be scanned?
      if can_order_be_scanned
        unless single_order.status == 'scanned'
          single_order.packing_user_id = @current_user.id
          single_order.save
        end
        #search in orders that have status of Scanned
        if single_order.status == 'scanned'
          single_order_result['scanned_on'] = single_order.scanned_on
          single_order_result['next_state'] = 'scanpack.rfo'
          @result['notice_messages'].push('This order has already been scanned')
        end

        #search in orders that have status of On Hold
        if single_order.status == 'onhold'
          if single_order.has_inactive_or_new_products
            #get list of inactive_or_new_products
            single_order_result['conf_code'] = @session[:confirmation_code]

            if @current_user.can?('add_edit_products') || (@session[:product_edit_matched_for_current_user] && @session[:product_edit_matched_for_order] == single_order.id)
              single_order_result['product_edit_matched'] = true
              single_order_result['inactive_or_new_products'] = single_order.get_inactive_or_new_products
              single_order_result['next_state'] = 'scanpack.rfp.product_edit'
            else
              @session[:product_edit_matched_for_current_user] = false
              @session[:order_edit_matched_for_current_user] = false
              @session[:product_edit_matched_for_order] = false
              @session[:product_edit_matched_for_products] = []
              single_order_result['next_state'] = 'scanpack.rfp.confirmation.product_edit'
              @result['notice_messages'].push("This order was automatically placed on hold because it contains items that have a "+
                                               "status of New or Inactive. These items may not have barcodes or other information needed for processing. "+
                                               "Please ask a user with product edit permissions to scan their code so that these items can be edited or scan a different order.")
            end
          else
            single_order_result['order_edit_permission'] = @current_user.can?('import_orders')
            single_order_result['next_state'] = 'scanpack.rfp.confirmation.order_edit'
            @result['notice_messages'].push('This order is currently on Hold. Please scan or enter '+
                                             'confirmation code with order edit permission to continue scanning this order or '+
                                             'scan a different order.')
          end
        end

        #process orders that have status of Service Issue
        if single_order.status == 'serviceissue'
          single_order_result['next_state'] = 'scanpack.rfp.confirmation.cos'
          if @current_user.can?('change_order_status')
            @result['notice_messages'].push('This order has a pending Service Issue. '+
                                             'To clear the Service Issue and continue packing the order please scan your confirmation code or scan a different order.')
          else
            @result['notice_messages'].push('This order has a pending Service Issue. To continue with this order, '+
                                             'please ask another user who has Change Order Status permissions to scan their '+
                                             'confirmation code and clear the issue. Alternatively, you can pack another order '+
                                             'by scanning another order number.')
          end
        end

        #search in orders that have status of Cancelled
        if single_order.status == 'cancelled'
          single_order_result['next_state'] = 'scanpack.rfo'
          @result['notice_messages'].push('This order has been cancelled')
        end

        #if order has status of Awaiting Scanning
        if single_order.status == 'awaiting'
          if !single_order.has_unscanned_items
            if @scanpack_settings.post_scanning_option != "None"
              if @scanpack_settings.post_scanning_option == "Verify"
                if single_order.tracking_num.nil?
                  single_order_result['next_state'] = 'scanpack.rfp.no_tracking_info'
                  single_order.addactivity("Tracking information was not imported with this order so the shipping label could not be verified ", @current_user.username)
                else
                  single_order_result['next_state'] = 'scanpack.rfp.verifying'
                end
              elsif @scanpack_settings.post_scanning_option == "Record"
                single_order_result['next_state'] = 'scanpack.rfp.recording'
              elsif @scanpack_settings.post_scanning_option == "PackingSlip"
                #generate packingslip for the order
                single_order.set_order_to_scanned_state(@current_user.username)
                single_order_result['next_state'] = 'scanpack.rfo'
                generate_packing_slip(single_order)
              else
                #generate barcode for the order
                single_order.set_order_to_scanned_state(@current_user.username)
                single_order_result['next_state'] = 'scanpack.rfo'
                generate_order_barcode_slip(single_order)
              end
            else
              single_order.set_order_to_scanned_state(@current_user.username)
              single_order_result['next_state'] = 'scanpack.rfo'
            end
          else
            single_order_result['next_state'] = 'scanpack.rfp.default'
            single_order.last_suggested_at = DateTime.now
            single_order.scan_start_time = DateTime.now if single_order.scan_start_time.nil?
          end
        end
        unless single_order.nil?
          unless single_order.save
            @result['status'] &= false
            @result['error_messages'].push("Could not save order with id: "+single_order.id)
          end
          single_order_result['order'] = order_details_and_next_item(single_order)
        end
      else
        @result['status'] &= false
        @result['error_messages'].push("You have reached the maximum limit of number of shipments for your subscription.")
        single_order_result['next_state'] = 'scanpack.rfo'
      end
      @result['data'] = single_order_result
      @result['data']['scan_pack_settings'] = @scanpack_settings
    end
  end

  def can_order_be_scanned
    #result = false
    #max_shipments = AccessRestriction.order("created_at").last.num_shipments
    #total_shipments = AccessRestriction.order("created_at").last.total_scanned_shipments
    #if total_shipments < max_shipments
    #  result = true
    #else
    #  result = false
    #end
    #result
    true
  end

  def order_details_and_next_item(single_order)
    single_order.reload
    data = single_order.attributes
    data['unscanned_items'] = single_order.get_unscanned_items
    data['scanned_items'] = single_order.get_scanned_items
    unless data['unscanned_items'].length == 0
      unless @session[:most_recent_scanned_products].nil?
        @session[:most_recent_scanned_products].reverse!.each do |scanned_product_id|
          data['unscanned_items'].each do |unscanned_item|
            if @session[:parent_order_item] && @session[:parent_order_item] == unscanned_item['order_item_id']
              @session[:parent_order_item] = false
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

  def generate_packing_slip(order)
    result = Hash.new
    result['status'] = false
    if GeneralSetting.get_packing_slip_size == '4 x 6'
      @page_height = '6'
      @page_width = '4'
    else
      @page_height = '11'
      @page_width = '8.5'
    end
    @size = GeneralSetting.get_packing_slip_size
    @orientation = GeneralSetting.get_packing_slip_orientation
    # Earlier this was @result so it messed up with @result from the method.
    # Changed it to @slip_data_hash
    @slip_data_hash = Hash.new
    @slip_data_hash['data'] = Hash.new
    @slip_data_hash['data']['packing_slip_file_paths'] = []

    if @orientation == 'landscape'
      @page_height = @page_height.to_f/2
      @page_height = @page_height.to_s
    end
    @header = ''

    @file_name = Apartment::Tenant.current+Time.now.strftime('%d_%b_%Y_%I__%M_%p')
    orders = []

    single_order = Order.find(order.id)
    unless single_order.nil?
      orders.push({id: single_order.id, increment_id: single_order.increment_id})
    end
    unless orders.empty?
      GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
      @generate_barcode = GenerateBarcode.new
      @generate_barcode.user_id = @current_user.id
      @generate_barcode.current_order_position = 0
      @generate_barcode.total_orders = orders.length
      @generate_barcode.next_order_increment_id = orders.first[:increment_id] unless orders.first.nil?
      @generate_barcode.status = 'scheduled'

      @generate_barcode.save
      delayed_job = GeneratePackingSlipPdf.delay(:run_at => 1.seconds.from_now).generate_packing_slip_pdf(orders, Apartment::Tenant.current, @slip_data_hash, @page_height, @page_width, @orientation, @file_name, @size, @header, @generate_barcode.id)
      @generate_barcode.delayed_job_id = delayed_job.id
      @generate_barcode.save
      result['status'] = true
    end
  end

  def generate_order_barcode_slip(order)
    require 'wicked_pdf'
    GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
    @generate_barcode = GenerateBarcode.new
    @generate_barcode.user_id = @current_user.id
    @generate_barcode.current_order_position = 0
    @generate_barcode.total_orders = 1
    @generate_barcode.current_increment_id = order.increment_id
    @generate_barcode.next_order_increment_id = nil
    @generate_barcode.status = 'in_progress'

    @generate_barcode.save
    file_name_order = Digest::MD5.hexdigest(order.increment_id)
    reader_file_path = Rails.root.join('public', 'pdfs', "#{Apartment::Tenant.current}.#{file_name_order}.pdf")
    ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
    av = ActionView::Base.new()
    av.view_paths = ActionController::Base.view_paths
    av.class_eval do
      include Rails.application.routes.url_helpers
      include ApplicationHelper
      include ProductsHelper
    end
    @order = order
    tenant_name = Apartment::Tenant.current
    file_name = tenant_name + Time.now.strftime('%d_%b_%Y_%I__%M_%p')
    pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}_order_number.pdf")
    pdf_html = av.render :template => '@orders/generate_order_barcode_slip.html.erb', :layout => nil, :locals => {:@order => @order}
    doc_pdf = WickedPdf.new.pdf_from_string(
      pdf_html,
      :inline => true,
      :save_only => false,
      :page_height => '1in',
      :page_width => '3in',
      :margin => {:top => '0',
                  :bottom => '0',
                  :left => '0',
                  :right => '0'}
    )
    File.open(reader_file_path, 'wb') do |file|
      file << doc_pdf
    end
    base_file_name = File.basename(pdf_path)
    pdf_file = File.open(reader_file_path)
    GroovS3.create_pdf(tenant_name, base_file_name, pdf_file.read)
    pdf_file.close
    @generate_barcode.url = ENV['S3_BASE_URL']+'/'+tenant_name+'/pdf/'+base_file_name
    @generate_barcode.status = 'completed'
    @generate_barcode.save
  end
end