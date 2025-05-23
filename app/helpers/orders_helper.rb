# frozen_string_literal: true

module OrdersHelper
  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

  def import_magento_product(client, session, sku, store_id, import_images, _import_products)
    response = client.call(:catalog_product_info,
                           message: { session: session, productId: sku })
    if response.success?
      @product = response.body[:catalog_product_info_response][:info]

      # add product to the database
      @productdb = Product.new
      @productdb.name = @product[:name]
      @productdb.store_product_id = @product[:product_id]
      @productdb.product_type = @product[:type]
      @productdb.store_id = store_id
      @productdb.weight = @product[:weight].to_f * 16

      # Magento product api does not provide a barcode, so all
      # magento products should be marked with a status new as t
      # they cannot be scanned.
      @productdb.status = 'new'

      @productdbsku = ProductSku.new
      # add productdb sku
      if @product[:sku] != { "@xsi:type": 'xsd:string' }
        @productdbsku.sku = @product[:sku]
        @productdbsku.purpose = 'primary'

        # publish the sku to the product record
        @productdb.product_skus << @productdbsku
      end

      # get images and categories
      if !@product[:sku].nil? && import_images
        getimages = client.call(:catalog_product_attribute_media_list, message: { session: session,
                                                                                  productId: sku })
        if getimages.success?
          @images = getimages.body[:catalog_product_attribute_media_list_response][:result][:item]
          unless @images.nil?
            if @images.is_a?(Array)
              @images.each do |image|
                @productimage = ProductImage.new
                @productimage.image = image[:url]
                @productimage.caption = image[:label]
                @productdb.product_images << @productimage
              end
            else
              @productimage = ProductImage.new
              @productimage.image = @images[:url]
              @productimage.caption = @images[:label]
              @productdb.product_images << @productimage
            end
          end
        end
      end

      if !@product[:categories][:item].nil? &&
         @product[:categories][:item].is_a?(Array)
        @product[:categories][:item].each do |category_id|
          get_categories = client.call(:catalog_product_info, message: { session: session,
                                                                         categoryId: category_id })
          if get_categories.success?
            @category = get_categories.body[:catalog_product_info_response][:info]
            @product_cat = ProductCat.new
            @product_cat.category = @category[:name]

            @productdb.product_cats << @product_cat unless @product_cat.category.nil?
          end
        rescue StandardError
        end
      end

      # add inventory warehouse
      inv_wh = ProductInventoryWarehouses.new
      inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
      @productdb.product_inventory_warehousess << inv_wh

      @productdb.save
      @productdb.set_product_status
      @productdb.id
    end
  rescue Exception => e
  end

  def build_pack_item(name, product_type, images, sku, qty_remaining,
                      scanned_qty, packing_placement,
                      barcodes, product_id, order_item_id, child_items, instruction, confirmation, skippable, record_serial,
                      box_id, kit_product_id, updated_at)

    unscanned_item = {}
    unscanned_item['name'] = name
    unscanned_item['instruction'] = instruction
    unscanned_item['confirmation'] = confirmation
    unscanned_item['images'] = images
    unscanned_item['sku'] = sku
    unscanned_item['packing_placement'] = packing_placement
    unscanned_item['barcodes'] = barcodes
    unscanned_item['product_id'] = product_id
    unscanned_item['skippable'] = skippable
    unscanned_item['record_serial'] = record_serial
    unscanned_item['order_item_id'] = order_item_id
    unscanned_item['product_type'] = product_type
    unscanned_item['qty_remaining'] = qty_remaining
    unscanned_item['scanned_qty'] = scanned_qty
    unscanned_item['box_id'] = box_id
    unscanned_item['kit_product_id'] = kit_product_id
    unscanned_item['updated_at'] = updated_at

    unscanned_item['child_items'] = child_items unless child_items.nil?

    unscanned_item
  end

  def build_order_with_single_item_from_ebay(order, transaction, order_transaction)
    order.status = 'awaiting'
    order.store = @store
    order.increment_id = transaction.shippingDetails.sellingManagerSalesRecordNumber
    order.order_placed_time = transaction.createdDate

    if !transaction.buyer.nil? && !transaction.buyer.buyerInfo.nil? &&
       !transaction.buyer.buyerInfo.shippingAddress.nil?
      order.address_1 = transaction.buyer.buyerInfo.shippingAddress.street1
      order.city = transaction.buyer.buyerInfo.shippingAddress.cityName
      order.state = transaction.buyer.buyerInfo.shippingAddress.stateOrProvince
      order.country = transaction.buyer.buyerInfo.shippingAddress.country
      order.postcode = transaction.buyer.buyerInfo.shippingAddress.postalCode
      # split name separated by a space
      unless transaction.buyer.buyerInfo.shippingAddress.name.nil?
        split_name = transaction.buyer.buyerInfo.shippingAddress.name.split(' ')
        order.lastname = split_name.pop
        order.firstname = split_name.join(' ')
      end
    end

    # single item transaction does not have transaction array
    order_item = OrderItem.new
    order_item.price = transaction.transactionPrice
    order_item.qty = transaction.quantityPurchased
    order_item.row_total = transaction.amountPaid
    order_item.sku = order_transaction.transaction.item.sKU
    # create product if it does not exist already
    order_item.product_id =
      import_ebay_product(order_transaction.transaction.item.itemID,
                          order_transaction.transaction.item.sKU, @eBay, @credential)
    order.order_items << order_item

    order
  end

  def build_order_with_multiple_items_from_ebay(order, order_detail)
    order.status = 'awaiting'
    order.store = @store
    order.increment_id = order_detail.shippingDetails.sellingManagerSalesRecordNumber
    order.order_placed_time = order_detail.createdTime

    unless order_detail.shippingAddress.nil?
      order.address_1 = order_detail.shippingAddress.street1
      order.city = order_detail.shippingAddress.cityName
      order.state = order_detail.shippingAddress.stateOrProvince
      order.country = order_detail.shippingAddress.country
      order.postcode = order_detail.shippingAddress.postalCode
      # split name separated by a space
      unless order_detail.shippingAddress.name.nil?
        split_name = order_detail.shippingAddress.name.split(' ')
        order.lastname = split_name.pop
        order.firstname = split_name.join(' ')
      end
    end

    # multiple order items from transaction array
    order_detail.transactionArray.each do |transaction|
      order_item = OrderItem.new
      order_item.price = transaction.transactionPrice
      order_item.qty = transaction.quantityPurchased
      order_item.row_total = transaction.amountPaid
      order_item.sku = transaction.item.sKU
      # create product if it does not exist already
      order_item.product_id =
        import_ebay_product(transaction.item.itemID,
                            transaction.item.sKU, @eBay, @credential)
      order.order_items << order_item
    end

    order
  end

  def generate_order_barcode_for_html(increment_id)
    order_barcode = Barby::Code128.new(increment_id)
    outputter = Barby::PngOutputter.new(order_barcode)
    outputter.margin = 0
    outputter.xdim = 2
    blob = outputter.to_png # Raw PNG data
    increment_id = increment_id.gsub(/[\#\s+]/, '')
    image_name = Digest::MD5.hexdigest(increment_id)
    unless File.exist?("#{Rails.root}/public/images/#{image_name}.png")
      File.open("#{Rails.root}/public/images/#{image_name}.png",
                'wb') do |f|
        f.write blob
      end
    end
    # increment_id
  end

  def init_product_attrs(product, _available_inv)
    location_primary = begin
                         product.try(:primary_warehouse).location_primary
                       rescue StandardError
                         ''
                       end
    order_item = { 'productinfo' => product,
                   'available_inv' => order_item_available_inv(product),
                   'sku' => product.primary_sku,
                   'barcode' => product.primary_barcode,
                   'category' => product.primary_category,
                   'image' => product.base_product.primary_image,
                   'packing_instructions' => product.packing_instructions,
                   'qty_on_hand' => product.try(:primary_warehouse).try(:quantity_on_hand),
                   'location_primary' => location_primary }
  end

  def make_orders_list(orders)
    @orders_result = []

    orders_scanning_count = Order.multiple_orders_scanning_count(orders)

    orders.each do |order|
      itemslength = begin
                      orders_scanning_count[order.id].values.sum
                    rescue StandardError
                      0
                    end
      order.scan_pack_v2 = (begin
                              params[:app].present?
                            rescue StandardError
                              @params[:app].present?
                            end)
      begin
         params[:app]
      rescue StandardError
        @params[:app]
       end ? generate_order_hash_v2(order, itemslength) : generate_order_hash(order, itemslength)
    end
    @orders_result
  end

  def generate_order_hash(order, itemslength)
    store_name = if !order.store.nil?
                   order.store&.display_origin_store_name ? order.origin_store&.store_name : order.store&.name
                 else
                   ''
                 end

    order_data = { 'id' => order.id,
                   'store_name' => store_name,
                   'notes' => order.notes_internal,
                   'ordernum' => order.increment_id,
                   'order_date' => order.order_placed_time,
                   'itemslength' => itemslength,
                   'status' => order.status,
                   'recipient' => "#{order.firstname} #{order.lastname}",
                   'email' => order.email,
                   'tracking_num' => order.tracking_num,
                   'city' => order.city,
                   'state' => order.state,
                   'postcode' => order.postcode,
                   'country' => order.country,
                   'tags' => order.order_tags,
                   'custom_field_one' => order.custom_field_one,
                   'custom_field_two' => order.custom_field_two,
                   'store_order_id' => order.store_order_id,
                   'last_modified' => order.last_modified,
                   'scanning_user' => order.packing_user&.username}
    tote = order.tote
    order_data['tote'] = tote.pending_order ? tote.name + '-PENDING' : tote.name if tote
    @orders_result.push(order_data)
  end

  def generate_order_hash_v2(order, itemslength)
    store_name = if !order.store.nil?
                   order.store&.display_origin_store_name ? order.origin_store&.store_name : order.store&.name
                 else
                   ''
                 end
    order_data = { 'id' => order.id,
                   'ordernum' => order.increment_id,
                   'itemslength' => itemslength }
    order_data[:print_ss_label] = order.print_ss_label?
    order_data[:order_info] = { 'id' => order.id,
                                'store_name' => store_name,
                                'notes' => order.notes_internal,
                                'ordernum' => order.increment_id,
                                'order_date' => order.order_placed_time,
                                'itemslength' => itemslength,
                                'status' => order.status,
                                'recipient' => "#{order.firstname} #{order.lastname}",
                                'email' => order.email,
                                'tracking_num' => order.tracking_num,
                                'city' => order.city,
                                'state' => order.state,
                                'postcode' => order.postcode,
                                'country' => order.country,
                                'tags' => order.order_tags,
                                'custom_field_one' => order.custom_field_one,
                                'custom_field_two' => order.custom_field_two,
                                'store_order_id' => order.store_order_id,
                                'last_modified' => order.last_modified,
                                'assigned_user_id' => order.assigned_user_id,
                                'scanning_user' => order.packing_user&.username}
    tote = order.tote
    order_data['tote'] = tote.pending_order ? tote.name + '-PENDING' : tote.name if tote
    order_data[:scan_hash] = {
      data: {
        order: order.as_json
      }
    }
    order_data[:scan_hash][:data][:order].merge!(unscanned_items: order.get_unscanned_items(limit: nil), scanned_items: order.get_scanned_items(limit: nil, is_reload: true), multi_shipments: {})
    order_data[:scan_hash][:data][:order][:multi_shipments] = order.get_se_old_shipments(order_data[:scan_hash][:data][:order][:multi_shipments])
    order_data[:scan_hash][:data][:order][:activities] = []
    generate_agor = Expo::GenerateAgor.new(order_data)
    formated_data = generate_agor.format_data
    @orders_result.push(formated_data)
  end

  def avg_time_per_item(username)
    user = User.where('username = ?', username).first

    orders = Order.where('status = ? AND packing_user_id = ? AND scanned_on > ?', 'scanned', user.id, DateTime.now.in_time_zone - 30.days)
    tscan_time = 0
    tscan_count = 0
    orders.each do |order|
      tscan_count += order.total_scan_count
      tscan_time += order.total_scan_time
    end
    tscan_time == 0 || tscan_count == 0 ? nil : tscan_time / tscan_count
  end

  def sort_order(params, orders)
    params['sort'] = 'increment_id' if params['sort'] == 'ordernum'
    params['sort'] = 'order_placed_time' if params['sort'] == 'order_date'
    begin
      orders = orders.order("#{params[:sort]} #{params[:order]}")
    rescue StandardError
      orders
    end
    orders
  end

  def update_access_restriction
    tenant = Apartment::Tenant.current
    stat_stream_obj = SendStatStream.new
    stat_stream_obj.delay(priority: 95, queue: "update_access_restriction_#{tenant}").update_restriction(tenant)
  end

  def add_new_product_for_item(item, result)
    product = Product.new
    product.name = item.name
    product.status = 'new'
    product.store_id = store_id
    product.store_product_id = 0

    if product.save
      product.set_product_status
      # now add skus
      @sku = ProductSku.new
      @sku.sku = item.sku
      @sku.purpose = 'primary'
      @sku.product_id = product.id
      result &= false unless @sku.save
    end
    item.product_id = product.id
    item.save
    import_amazon_product_details(store_id, item.sku, item.product_id)
  end

  def update_scanned_list(order_item, scanned_list)
    if order_item.cached_product.is_kit == 1
      option_products = order_item.cached_option_products
      case order_item.cached_product.kit_parsing
      when 'single'
        # if single, then add order item to unscanned list
        scanned_list.push(order_item.build_scanned_single_item)
      when 'individual'
        # else if individual then add all order items as children to unscanned list
        scanned_list.push(order_item.build_scanned_individual_kit(option_products))
      when 'depends'
        if order_item.kit_split
          scanned_list.push(order_item.build_scanned_individual_kit(option_products, true)) if order_item.kit_split_qty > 0
          scanned_list.push(order_item.build_scanned_single_item(true)) if order_item.single_scanned_qty != 0
        else
          scanned_list.push(order_item.build_scanned_single_item)
        end
      end
    else
      # add order item to unscanned list
      scanned_list.push(order_item.build_unscanned_single_item)
    end
  end

  def update_unscanned_list(limited_order_items, unscanned_list, scan_pack_v2 = false)
    limited_order_items.each do |order_item|
      if order_item.cached_product.try(:is_kit) == 1
        option_products = order_item.cached_option_products
        case order_item.cached_product.kit_parsing
        when 'single'
          # if single, then add order item to unscanned list
          unscanned_list.push(order_item.build_unscanned_single_item)
        when 'individual'
          unless order_item.cached_product.is_intangible
            # else if individual then add all order items as children to unscanned list
            unscanned_list.push(order_item.build_unscanned_individual_kit(option_products))
          end
        when 'depends'
          if order_item.kit_split
            unscanned_list.push(order_item.build_unscanned_individual_kit(option_products, true)) if order_item.kit_split_qty > order_item.kit_split_scanned_qty

            if order_item.qty > order_item.kit_split_qty
              unscanned_item = order_item.build_unscanned_single_item(true)
              return unless unscanned_item['qty_remaining'] > 0

              if scan_pack_v2
                order_item.scan_pack_v2 = true
                unscanned_list.push(order_item.build_unscanned_individual_kit(option_products))
              else
                unscanned_list.push(unscanned_item)
              end
            end
            # unscanned_qty = order_item.qty - order_item.scanned_qty
            # added_to_list_qty = true
            # unscanned_qty.times do
            #   if added_to_list_qty < unscanned_qty
            #     individual_kit_count = 0

            #     #determine no of split kits already in unscanned_list
            #     unscanned_list.each do |unscanned_item|
            #       if unscanned_item['product_id'] == order_item.product_id &&
            #           unscanned_item['product_type'] == 'individual'
            #           individual_kit_count = individual_kit_count + 1
            #       end
            #     end

            #     #unscanned list building kits
            #     if individual_kit_count < order_item.kit_split_qty
            #       unscanned_list.push(order_item.build_unscanned_individual_kit, true)
            #       added_to_list_qty = added_to_list_qty + order_item.kit_split_qty
            #     else
            #       unscanned_list.push(order_item.build_unscanned_single_item, true)
            #     end
            #   end
            # end
          elsif self.scan_pack_v2
            order_item.scan_pack_v2 = true
            unscanned_list.push(order_item.build_unscanned_individual_kit(option_products))
          else
            unscanned_item = order_item.build_unscanned_single_item
            unscanned_list.push(unscanned_item) if unscanned_item['qty_remaining'] > 0
          end
        end
      else
        unless order_item.cached_product.is_intangible
          # add order item to unscanned list
          unscanned_item = order_item.build_unscanned_single_item
          if unscanned_item['qty_remaining'] > 0
            loc = unscanned_item['location'].present? ? unscanned_item['location'] : ''
            placement = begin
                          format('%.3i', unscanned_item['packing_placement'])
                        rescue StandardError
                          unscanned_item['packing_placement']
                        end
            unscanned_item['next_item'] = "#{placement} #{loc} #{unscanned_item['sku']}"
            unscanned_list.push(unscanned_item)
          end
        end
      end
    end
  end

  # def se_duplicate_orders(order)
  #   return [] unless order.store.store_type == 'ShippingEasy'

  #   duplicate_orders = []
  #   se_shipments = Order.where('orders.prime_order_id = ? AND orders.store_order_id = ? AND orders.id != ?', order.prime_order_id, order.store_order_id, order.id).order(:increment_id)
  #   return duplicate_orders if se_shipments.blank?

  #   se_shipments.each do |shipment|
  #     if shipment.status == 'scanned'
  #       shipment_status = 'Scanned'
  #     else
  #       shipment_status = shipment.scanning_count[:scanned].to_i > 0 ? 'Partial Scanned' : 'Unscanned'
  #     end
  #     duplicate_orders << [shipment.id, shipment.increment_id, shipment_status, shipment.order_placed_time.try(:strftime, '%A, %d %b %Y %l:%M %p'), shipment.scanned_on.try(:strftime, '%A, %d %b %Y %l:%M %p'), shipment.tracking_num]
  #   end
  #   duplicate_orders
  # end

  # def se_old_shipments(order)
  #   old_shipments = []
  #   shipments = Order.where(store_order_id: order.split_from_order_id.split(',').map(&:to_i)) if order.split_from_order_id.present?
  #   shipments = Order.where('orders.prime_order_id = ? AND orders.store_order_id != ? AND orders.status != ?', order.prime_order_id, order.store_order_id, 'scanned') if Order.where(prime_order_id: order.prime_order_id).count > 1 && Order.where(store_order_id: order.prime_order_id, prime_order_id: order.prime_order_id).any? && shipments.blank?
  #   return old_shipments if shipments.blank?
  #   shipments.each do |shipment|
  #     if shipment.status == 'scanned'
  #       shipment_status = 'Scanned'
  #     else
  #       shipment_status = shipment.scanning_count[:scanned].to_i > 0 ? 'Partial Scanned' : 'Unscanned'
  #     end
  #     old_shipments << [shipment.id, shipment.increment_id, shipment_status]
  #   end
  #   old_shipments
  # end

  # def se_all_shipments(order)
  #   all_shipments = { shipments: [] }
  #   shipments = Order.where('orders.prime_order_id = ? AND orders.store_order_id != ? AND orders.status != ?', order.prime_order_id, order.store_order_id, 'scanned') if Order.where(prime_order_id: order.prime_order_id).count > 1
  #   return all_shipments if shipments.blank?
  #   order_split_inc = order.increment_id.split(" (S")
  #   order_shipment_no = order_split_inc.last.chop.to_i rescue 1
  #   order_inc_id = order_split_inc[0..(order_split_inc.length-2)].join rescue order.increment_id
  #   all_shipments[:present] = true
  #   all_shipments[:order_shipment_no] = order_shipment_no
  #   all_shipments[:order_shipment_count] = shipments.count + 1
  #   all_shipments[:order_inc_id] = order_inc_id
  #   shipments.each do |shipment|
  #     split_inc = shipment.increment_id.split(" (S")
  #     shipment_no = split_inc.last.chop.to_i rescue 1
  #     inc_id = split_inc[0..(split_inc.length-2)].join rescue shipment.increment_id
  #     items_count = shipment.get_items_count
  #     all_shipments[:shipments] << [shipment_no, inc_id, shipment.increment_id, items_count]
  #   end
  #   all_shipments
  # end
end
