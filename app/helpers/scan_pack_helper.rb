module ScanPackHelper

  include OrdersHelper

  def order_scan(input,state,id,over_ride)
    puts "over_ride: " + over_ride.to_s
    result = Hash.new
    result['status'] = true
    result['matched'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new
    result['data']['next_state'] = 'scanpack.rfo'

    scanpack_settings = ScanPackSetting.all.first

    session[:most_recent_scanned_products] = []
    if !input.nil? && input != ""
      if scanpack_settings.cue_orders_by == 'order_number' || over_ride
        orders = Order.where(['increment_id = ? or non_hyphen_increment_id =?', input, input])
      else
        orders = Order.where(['tracking_num = ?', input])
      end
      single_order = nil
      single_order_result = Hash.new
      single_order_result['matched_orders'] = []

      if orders.length == 1
        single_order = orders.first
      else
        orders.each do |matched_single|
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
          unless ['scanned','cancelled'].include?(matched_single.status)
            single_order_result['matched_orders'].push(matched_single.increment_id)
          end
        end
      end

      if single_order.nil?
        if scanpack_settings.cue_orders_by == 'order_number'
          result['notice_messages'].push('Order with number '+
            input +' cannot be found. It may not have been imported yet')
        else
          result['notice_messages'].push('Order with tracking number '+
            input +' cannot be found. It may not have been imported yet')
        end
      else
        single_order_result['status'] = single_order.status
        single_order_result['order_num'] = single_order.increment_id

        #can order be scanned?
        if can_order_be_scanned
          unless single_order.status == 'scanned'
            single_order.packing_user_id = current_user.id
            single_order.save
          end
          #search in orders that have status of Scanned
          if single_order.status == 'scanned'
            single_order_result['scanned_on'] = single_order.scanned_on
            single_order_result['next_state'] = 'scanpack.rfo'
            result['notice_messages'].push('This order has already been scanned')
          end

          #search in orders that have status of On Hold
          if single_order.status == 'onhold'
            if single_order.has_inactive_or_new_products
              #get list of inactive_or_new_products
              single_order_result['conf_code'] = session[:confirmation_code]

              if current_user.can?('add_edit_products') || (session[:product_edit_matched_for_current_user] && session[:product_edit_matched_for_order] == single_order.id)
                single_order_result['product_edit_matched'] = true
                single_order_result['inactive_or_new_products'] = single_order.get_inactive_or_new_products
                single_order_result['next_state'] = 'scanpack.rfp.product_edit'
              else
                session[:product_edit_matched_for_current_user] = false
                session[:order_edit_matched_for_current_user] = false
                session[:product_edit_matched_for_order] = false
                session[:product_edit_matched_for_products] = []
                single_order_result['next_state'] = 'scanpack.rfp.confirmation.product_edit'
                result['notice_messages'].push("This order was automatically placed on hold because it contains items that have a "+
                                                    "status of New or Inactive. These items may not have barcodes or other information needed for processing. "+
                                                    "Please ask a user with product edit permissions to scan their code so that these items can be edited or scan a different order.")
              end
            else
              single_order_result['order_edit_permission'] = current_user.can?('import_orders')
              single_order_result['next_state'] = 'scanpack.rfp.confirmation.order_edit'
              result['notice_messages'].push('This order is currently on Hold. Please scan or enter '+
                                                  'confirmation code with order edit permission to continue scanning this order or '+
                                                  'scan a different order.')
            end
          end

          #process orders that have status of Service Issue
          if single_order.status == 'serviceissue'
            single_order_result['next_state'] = 'scanpack.rfp.confirmation.cos'
            if current_user.can?('change_order_status')
              result['notice_messages'].push('This order has a pending Service Issue. '+
                                                  'To clear the Service Issue and continue packing the order please scan your confirmation code or scan a different order.')
            else
              result['notice_messages'].push('This order has a pending Service Issue. To continue with this order, '+
                                                  'please ask another user who has Change Order Status permissions to scan their '+
                                                  'confirmation code and clear the issue. Alternatively, you can pack another order '+
                                                  'by scanning another order number.')
            end
          end

          #search in orders that have status of Cancelled
          if single_order.status == 'cancelled'
            single_order_result['next_state'] = 'scanpack.rfo'
            result['notice_messages'].push('This order has been cancelled')
          end

          #if order has status of Awaiting Scanning
          if single_order.status == 'awaiting'
            if !single_order.has_unscanned_items
              if scanpack_settings.post_scanning_option != "None"
                if scanpack_settings.post_scanning_option == "Verify"
                  if single_order.tracking_num.nil?
                    single_order_result['next_state'] = 'scanpack.rfp.no_tracking_info'
                    single_order.addactivity("Tracking information was not imported with this order so the shipping label could not be verified ", current_user.username)
                  else
                    single_order_result['next_state'] = 'scanpack.rfp.verifying'
                  end
                elsif scanpack_settings.post_scanning_option == "Record"
                  single_order_result['next_state'] = 'scanpack.rfp.recording'
                elsif scanpack_settings.post_scanning_option == "PackingSlip"
                  #generate packingslip for the order
                  single_order.set_order_to_scanned_state(current_user.username)
                  single_order_result['next_state'] = 'scanpack.rfo'
                  generate_packing_slip(single_order)
                else
                  #generate barcode for the order
                  single_order.set_order_to_scanned_state(current_user.username)
                  single_order_result['next_state'] = 'scanpack.rfo'
                  generate_order_barcode_slip(single_order)
                end
              else
                single_order.set_order_to_scanned_state(current_user.username)
                single_order_result['next_state'] = 'scanpack.rfo'
              end
            else
              single_order_result['next_state'] = 'scanpack.rfp.default'
              single_order.scan_start_time = DateTime.now if single_order.scan_start_time.nil?
            end
          end
          unless single_order.nil?
            unless single_order.save
              result['status'] &= false
              result['error_messages'].push("Could not save order with id: "+single_order.id)
            end
            single_order_result['order'] = order_details_and_next_item(single_order)
          end
        else
          result['status'] &= false
          result['error_messages'].push("You have reached the maximum limit of number of shipments for your subscription.")
          single_order_result['next_state'] = 'scanpack.rfo'
        end
        result['data'] = single_order_result
        result['data']['scan_pack_settings'] = scanpack_settings
      end
    else
      result['status'] &= false
      result['error_messages'].push("Please specify a barcode to scan the order")
    end
    return result
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

  def product_scan(input,state,id,clicked=false,serial_added=false)
    result = Hash.new
    result['status'] = true
    result['matched'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new
    result['data']['next_state'] = 'scanpack.rfp.default'
    result['data']['serial'] = Hash.new
    result['data']['serial']['ask'] = false

    session[:product_edit_matched_for_current_user] = false
    session[:order_edit_matched_for_current_user] = false
    session[:product_edit_matched_for_order] = false
    session[:product_edit_matched_for_products] = []
    if id.nil? || input.nil?
      result['status'] &= false
      result['error_messages'].push('Please specify barcode and order id to confirm purchase code')
    else
      #check if order status is On Hold
      single_order = Order.find(id)
      scanpack_settings = ScanPackSetting.all.first
      if single_order.nil?
        result['status'] &= false
        result['error_messages'].push('Could not find order with id:'+id)
      elsif scanpack_settings.restart_code_enabled? && input == scanpack_settings.restart_code
        if single_order.status != 'scanned'
          single_order.reset_scanned_status
          result['data']['next_state'] = 'scanpack.rfo'
        else
          result['status'] &= false
          result['error_messages'].push('Order with id: '+id.to_s+' is already in scanned state')
        end

      elsif scanpack_settings.service_issue_code_enabled? && input == scanpack_settings.service_issue_code
        if single_order.status !='scanned'
          single_order.reset_scanned_status
          single_order.status = 'serviceissue'
          result['data']['next_state'] = 'scanpack.rfo'
          result['data']['ask_note'] = true
        else
          result['status'] &= false
          result['error_messages'].push('Order with id: '+id+' is already in scanned state')
        end
      else
        escape_string = ''
        if scanpack_settings.escape_string_enabled && !input.index(scanpack_settings.escape_string).nil?
          clean_input = input.slice(0..(input.index(scanpack_settings.escape_string)-1))
        else
          clean_input = input
        end

        result['data']['serial']['clicked'] = clicked
        result['data']['serial']['barcode'] = clean_input
        result['data']['serial']['order_id'] = id

        result['data']['order_num'] = single_order.increment_id

        if single_order.has_unscanned_items
          single_order.should_the_kit_be_split(clean_input) if single_order.contains_kit && single_order.contains_splittable_kit

          unscanned_items = single_order.get_unscanned_items
          barcode_found = false
          #search if barcode exists
          unscanned_items.each do |item|
            if item['product_type'] == 'individual'
              if item['child_items'].length > 0
                item['child_items'].each do |child_item|
                  if !child_item['barcodes'].nil?
                    child_item['barcodes'].each do |barcode|
                      if barcode.barcode == clean_input || (scanpack_settings.skip_code_enabled? && clean_input == scanpack_settings.skip_code && child_item['skippable'])
                        barcode_found = true
                        #process product barcode scan
                        order_item_kit_product =
                            OrderItemKitProduct.find(child_item['kit_product_id'])

                        unless serial_added
                          order_item = order_item_kit_product.order_item unless order_item_kit_product.order_item.nil?
                          result['data']['serial']['order_item_id'] = order_item.id
                          if scanpack_settings.record_lot_number
                            lot_number = calculate_lot_number(scanpack_settings, input)
                            product = order_item.product unless order_item.nil? || order_item.product.nil?
                            unless lot_number.nil?
                              if product.product_lots.where(lot_number: lot_number).empty?
                                product.product_lots.create(product_id: product.id, lot_number: lot_number)
                              end
                              product_lot = product.product_lots.where(lot_number: lot_number).first
                              OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
                              result['data']['serial']['product_lot_id'] = product_lot.id
                            else
                              result['data']['serial']['product_lot_id'] = nil
                            end
                          else
                            result['data']['serial']['product_lot_id'] = nil
                          end
                        end

                        unless order_item_kit_product.nil?
                          if child_item['record_serial']
                            if serial_added
                              order_item_kit_product.process_item(clicked, current_user.username)
                              (session[:most_recent_scanned_products] ||= []) << child_item['product_id']
                            else
                              result['data']['serial']['ask'] = true
                              result['data']['serial']['product_id'] = child_item['product_id']
                            end
                          else
                            order_item_kit_product.process_item(clicked, current_user.username)
                            (session[:most_recent_scanned_products] ||= []) << child_item['product_id']
                          end
                        end

                        break
                      end
                    end
                  end
                  break if barcode_found
                end
              end
            elsif item['product_type'] == 'single'
              item['barcodes'].each do |barcode|
                if barcode.barcode == clean_input || (scanpack_settings.skip_code_enabled? && clean_input == scanpack_settings.skip_code && item['skippable'])
                  barcode_found = true
                  #process product barcode scan
                  order_item = OrderItem.find(item['order_item_id'])

                  unless serial_added
                    result['data']['serial']['order_item_id'] = order_item.id
                    if scanpack_settings.record_lot_number
                      lot_number = calculate_lot_number(scanpack_settings, input)
                      product = order_item.product unless order_item.product.nil?
                      unless lot_number.nil?
                        if product.product_lots.where(lot_number: lot_number).empty?
                          product.product_lots.create(lot_number: lot_number)
                        end
                        product_lot = product.product_lots.where(lot_number: lot_number).first
                        OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
                        result['data']['serial']['product_lot_id'] = product_lot.id
                      else
                        result['data']['serial']['product_lot_id'] = nil
                      end
                    else
                      result['data']['serial']['product_lot_id'] = nil
                    end
                  end
                  
                  process_scan(clicked, order_item, serial_added, result)
                  break
                end
              end
            end
            break if barcode_found
          end

          unless barcode_found
            product_barcodes = ProductBarcode.where(barcode: clean_input)
            unless product_barcodes.empty?
              product_barcode = product_barcodes.first
              product = product_barcode.product unless product_barcode.product.nil?
              unless product.nil?
                if product.add_to_any_order
                  barcode_found = true
                  # check if the item is part of the order item list or not
                  #IF the item is already in the items list, then just increment the qty for the item
                  # if the item is not in the items list, then add the item to the list.Add activities
                  item_in_order = false
                  single_order.order_items.each do |item|
                    if item.product == product
                      store_lot_number(scanpack_settings, input, item, serial_added, result)
                      item.update_inventory_levels_for_return(true)
                      item.qty += 1
                      item.update_inventory_levels_for_packing(true)
                      item.scanned_status = 'partially_scanned'
                      item.save
                      single_order.addactivity("Item with SKU: #{item.sku} Added", current_user.username)
                      item_in_order = true
                      process_scan(clicked, item, serial_added, result)
                      break
                    end
                  end
                  unless item_in_order
                    single_order.add_item_to_order(product)
                    order_items = single_order.order_items.where(product_id: product.id)
                    order_item = order_items.first unless order_items.empty?
                    unless order_item.nil?
                      store_lot_number(scanpack_settings, input, order_item, serial_added, result)
                      single_order.addactivity("Item with SKU: #{order_item.sku} Added", current_user.username)
                      process_scan(clicked, order_item, serial_added, result)
                    end
                  end
                end
              end
            end
          end

          if barcode_found
            if !single_order.has_unscanned_items
              if scanpack_settings.post_scanning_option != "None"
                if scanpack_settings.post_scanning_option == "Verify"
                  if single_order.tracking_num.nil?
                    result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
                    single_order.addactivity("Tracking information was not imported with this order so the shipping label could not be verified ", current_user.username)
                  else
                    result['data']['next_state'] = 'scanpack.rfp.verifying'
                  end
                elsif scanpack_settings.post_scanning_option == "Record"
                  result['data']['next_state'] = 'scanpack.rfp.recording'
                elsif scanpack_settings.post_scanning_option == "PackingSlip"
                  #generate packing slip for the order
                  single_order.set_order_to_scanned_state(current_user.username)
                  result['data']['order_complete'] = true
                  result['data']['next_state'] = 'scanpack.rfo'
                  generate_packing_slip(single_order)
                else
                  #generate barcode for the order
                  single_order.set_order_to_scanned_state(current_user.username)
                  result['data']['order_complete'] = true
                  result['data']['next_state'] = 'scanpack.rfo'
                  generate_order_barcode_slip(single_order)
                end
              else
                single_order.set_order_to_scanned_state(current_user.username)
                result['data']['order_complete'] = true
                result['data']['next_state'] = 'scanpack.rfo'
              end
            end
          else
            single_order.inaccurate_scan_count = single_order.inaccurate_scan_count + 1
            result['status'] &= false
            result['error_messages'].push("Barcode '"+clean_input+"' doesn't match any item on this order")
          end
        else
          result['status'] &= false
          result['error_messages'].push("There are no unscanned items in this order")
        end
      end
    end

    unless single_order.nil?
      single_order.packing_user_id = current_user.id
      unless single_order.save
        result['status'] &= false
        result['error_messages'].push('Could not save order with id: '+single_order.id)
      end
      result['data']['order'] = order_details_and_next_item(single_order)
      result['data']['scan_pack_settings'] = scanpack_settings
    end

    return result
  end

  def store_lot_number(scanpack_settings, input, order_item, serial_added,result)
    if scanpack_settings.record_lot_number
      unless serial_added
        product = order_item.product
        lot_number = calculate_lot_number(scanpack_settings, input)
        result['data']['serial']['order_item_id'] = order_item.id
        unless lot_number.nil?
          if product.product_lots.where(lot_number: lot_number).empty?
            product.product_lots.create(lot_number: lot_number)
          end
          product_lot = product.product_lots.where(lot_number: lot_number).first
          OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
          result['data']['serial']['product_lot_id'] = product_lot.id
        else
          result['data']['serial']['product_lot_id'] = nil
        end
      end
    end
    result
  end

  def process_scan(clicked, order_item, serial_added, result)
    unless order_item.nil?
      if order_item.product.record_serial
        if serial_added
          order_item.process_item(clicked, current_user.username)
          (session[:most_recent_scanned_products] ||= []) << order_item.product_id
        else
          result['data']['serial']['ask'] = true
          result['data']['serial']['product_id'] = order_item.product_id
        end
      else
        order_item.process_item(clicked, current_user.username)
        (session[:most_recent_scanned_products] ||= []) << order_item.product_id
      end
    end
    result
  end

  def calculate_lot_number(scanpack_settings, input)
    if scanpack_settings.escape_string_enabled && !input.index(scanpack_settings.escape_string).nil?
      return input.slice((input.index(scanpack_settings.escape_string)+scanpack_settings.escape_string.length)..(input.length-1))
    end
  end

  def scan_recording(input,state,id,over_ride)
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

  def scan_verifying(input,state,id,over_ride)
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

  def render_order_scan(input,state,id,over_ride)
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

  def scan_again_or_render_order_scan(input,state,id,over_ride)
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

  def order_edit_conf(input,state,id,over_ride)
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
        if single_order.status == "onhold" && !single_order.has_inactive_or_new_products
          if User.where(:confirmation_code => input).length > 0
            result['matched'] = true
            single_order.status = 'awaiting'
            single_order.addactivity("Status changed from onhold to awaiting",
                               User.where(:confirmation_code => input).first.username)
            single_order.save
            result['data']['scanned_on'] = single_order.scanned_on
            result['data']['next_state'] = 'scanpack.rfp.default'
            session[:order_edit_matched_for_current_user] = true
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

  def cos_conf(input,state,id,over_ride)
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

  def product_edit_conf(input,state,id,over_ride)
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
            if unscanned_item['product_type'] == 'single' &&
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
    @result = Hash.new
    @result['data'] = Hash.new
    @result['data']['packing_slip_file_paths'] = []

    if @orientation == 'landscape'
      @page_height = @page_height.to_f/2
      @page_height = @page_height.to_s
    end
    @header = ''

    @file_name = Apartment::Tenant.current_tenant+Time.now.strftime('%d_%b_%Y_%I__%M_%p')
    @orders = []

    single_order = Order.find(order.id)
    unless single_order.nil?
      @orders.push({id:single_order.id, increment_id:single_order.increment_id})
    end
    unless @orders.empty?
      GenerateBarcode.where('updated_at < ?',24.hours.ago).delete_all
      @generate_barcode = GenerateBarcode.new
      @generate_barcode.user_id = current_user.id
      @generate_barcode.current_order_position = 0
      @generate_barcode.total_orders = @orders.length
      @generate_barcode.next_order_increment_id = @orders.first[:increment_id] unless @orders.first.nil?
      @generate_barcode.status = 'scheduled'

      @generate_barcode.save
      delayed_job = GeneratePackingSlipPdf.delay(:run_at => 1.seconds.from_now).generate_packing_slip_pdf(@orders, Apartment::Tenant.current_tenant, @result, @page_height,@page_width,@orientation,@file_name, @size, @header,@generate_barcode.id)
      @generate_barcode.delayed_job_id = delayed_job.id
      @generate_barcode.save
      result['status'] = true
    end
  end

  def generate_order_barcode_slip(order)
    require 'wicked_pdf'
    GenerateBarcode.where('updated_at < ?',24.hours.ago).delete_all
    @generate_barcode = GenerateBarcode.new
    @generate_barcode.user_id = current_user.id
    @generate_barcode.current_order_position = 0
    @generate_barcode.total_orders = 1
    @generate_barcode.current_increment_id = order.increment_id
    @generate_barcode.next_order_increment_id = nil
    @generate_barcode.status = 'in_progress'

    @generate_barcode.save
    file_name_order = Digest::MD5.hexdigest(order.increment_id)
    reader_file_path = Rails.root.join('public', 'pdfs', "#{Apartment::Tenant.current_tenant}.#{file_name_order}.pdf")
    ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
    av = ActionView::Base.new()
    av.view_paths = ActionController::Base.view_paths
    av.class_eval do
      include Rails.application.routes.url_helpers
      include ApplicationHelper
      include ProductsHelper
    end
    @order = order
    tenant_name = Apartment::Tenant.current_tenant
    file_name = tenant_name + Time.now.strftime('%d_%b_%Y_%I__%M_%p')
    pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}_order_number.pdf")
    pdf_html = av.render :template => 'orders/generate_order_barcode_slip.html.erb', :layout => nil, :locals => {:@order => @order}
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
    GroovS3.create_pdf(tenant_name,base_file_name,pdf_file.read)
    pdf_file.close
    @generate_barcode.url = ENV['S3_BASE_URL']+'/'+tenant_name+'/pdf/'+base_file_name
    @generate_barcode.status = 'completed'
    @generate_barcode.save
  end
end
