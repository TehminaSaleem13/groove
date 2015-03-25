module ScanPackHelper

  include OrdersHelper

  def order_scan(input,state,id)
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
      orders = Order.where(['increment_id = ? or non_hyphen_increment_id =?', input, input])
      logger.info orders
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
        result['notice_messages'].push('Order with number '+
          input +' cannot be found. It may not have been imported yet')
      else
        single_order_result['status'] = single_order.status
        single_order_result['order_num'] = single_order.increment_id

        #can order be scanned?
        if can_order_be_scanned
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
                  else
                    single_order_result['next_state'] = 'scanpack.rfp.verifying'
                  end
                else
                  single_order_result['next_state'] = 'scanpack.rfp.recording'
                end
              else
                single_order.set_order_to_scanned_state(current_user.username)
                single_order_result['next_state'] = 'scanpack.rfo'
              end
            else
              single_order_result['next_state'] = 'scanpack.rfp.default'
            end
          end
          unless single_order.nil?
            single_order.packing_user_id = current_user.id
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

                  unless order_item.nil?
                    if item['record_serial']
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
                  break
                end
              end
            end
            break if barcode_found
          end

          #puts "Barcode "+clean_input+" found: "+barcode_found.to_s
          if barcode_found
            puts "single_order.inspect: "
            puts single_order.inspect
            puts single_order.has_unscanned_items
            if !single_order.has_unscanned_items
              if scanpack_settings.post_scanning_option != "None"
                if scanpack_settings.post_scanning_option == "Verify"
                  if single_order.tracking_num.nil?
                    result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
                  else
                    result['data']['next_state'] = 'scanpack.rfp.verifying'
                  end
                else
                  result['data']['next_state'] = 'scanpack.rfp.recording'
                end
              else
                puts "no unscanned_items..."
                single_order.set_order_to_scanned_state(current_user.username)
                result['data']['order_complete'] = true
                result['data']['next_state'] = 'scanpack.rfo'
              end
            end
          else
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
    end

    return result
  end

  def scan_recording(input,state,id)
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

  def scan_verifying(input,state,id)
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
          if order.tracking_num == input
            order.set_order_to_scanned_state(current_user.username)
            result['data']['order_complete'] = true
            result['data']['next_state'] = 'scanpack.rfo'
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

  def render_order_scan(input,state,id)
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
      if state == "scanpack.rfp.no_tracking_info" && input == ""
        result['status'] = false
        result['matched'] = false
        result['data']['next_state'] = 'scanpack.rfo'
      elsif state == "scanpack.rfp.no_tracking_info" && input == current_user.confirmation_code
        result['status'] = true
        result['matched'] = false
        order.set_order_to_scanned_state(current_user.username)
        result['data']['order_complete'] = true
        result['data']['next_state'] = 'scanpack.rfo'
        order.save
      end
    end
    result
  end

  def scan_again_or_render_order_scan(input,state,id)
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
          result['data']['next_state'] = 'scanpack.rfo'
          order.save
        elsif state == "scanpack.rfp.no_match" && input == order.tracking_num
          result['status'] = true
          result['matched'] = true
          order.set_order_to_scanned_state(current_user.username)
          result['data']['order_complete'] = true
          result['data']['next_state'] = 'scanpack.rfo'
          order.save
        else
          result['status'] = false
          result['matched'] = false
          result['data']['next_state'] = 'scanpack.rfp.verifying'
        end
      end
    end
    result
  end

  def order_edit_conf(input,state,id)
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

  def cos_conf(input,state,id)
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

  def product_edit_conf(input,state,id)
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
          data['next_item'] = data['unscanned_items'].first['child_items'].first.clone
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

end
