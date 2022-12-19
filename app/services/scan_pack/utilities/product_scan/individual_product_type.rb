# frozen_string_literal: true

module ScanPack::Utilities::ProductScan::IndividualProductType
  def do_if_product_type_is_individual(params)
    item, clean_input, serial_added, clicked, barcode_found, type_scan = params
    item['child_items'].each do |child_item|
      item = OrderItem.find_by_id(child_item['order_item_id'])
      if child_item['qty_remaining'] == 1 && clicked && item.product.is_kit == 1
        item.clicked_qty = item.clicked_qty + 1
        item.save
      end

      barcode_found = do_if_child_item_has_barcodes(params, child_item) if child_item['barcodes'].present?

      break if barcode_found
    end
    barcode_found
  end

  def do_if_child_item_has_barcodes(params, child_item)
    item, clean_input, serial_added, clicked, barcode_found, type_scan = params
    child_item['barcodes'].each do |barcode|
      next unless barcode.barcode.strip.casecmp(clean_input.strip).zero? || (
        @scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && child_item['skippable']
      )

      barcode_found = true
      # process product barcode scan
      order_item_kit_product = OrderItemKitProduct.find_by_id(child_item['kit_product_id'])

      order_item = order_item_kit_product.order_item if order_item_kit_product.order_item.present?

      # do_if_serial_not_added(order_item_kit_product) unless serial_added
      # from LotNumber Module

      store_lot_number(order_item, serial_added)

      if order_item_kit_product.present?
        do_if_order_item_kit_product_present(
          [item, child_item, serial_added, clicked, order_item_kit_product, type_scan]
        )
        insert_in_box(order_item, order_item_kit_product.id) if GeneralSetting.last.multi_box_shipments? && !child_item['record_serial'] && !should_remove_kit_item?(clean_input, child_item['skippable'])
        if child_item['record_serial'] && serial_added && GeneralSetting.last.multi_box_shipments?
          insert_in_box(order_item, order_item_kit_product.id) unless should_remove_kit_item?(clean_input, child_item['skippable'])
        end
        remove_kit_item_from_order(child_item) if should_remove_kit_item?(clean_input, child_item['skippable'])
      end
      break
    end
    barcode_found
  end

  # def do_if_serial_not_added(order_item_kit_product)
  #   order_item = order_item_kit_product.order_item unless order_item_kit_product.order_item.nil?
  #   @result['data']['serial']['order_item_id'] = order_item.id
  #   if @scanpack_settings.record_lot_number
  #     lot_number = calculate_lot_number
  #     product = order_item.product if order_item.present? || order_item.product.present?

  #     # unless lot_number.nil?
  #     #   product_lots = product.product_lots
  #     #   product_lot = product_lots.where(lot_number: lot_number).first || product_lots.create(lot_number: lot_number)
  #     #   OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
  #     #   @result['data']['serial']['product_lot_id'] = product_lot.id
  #     # else
  #     #   @result['data']['serial']['product_lot_id'] = nil
  #     # end
  #     @result['data']['serial']['product_lot_id'] = lot_number.present? ?
  #                                                 do_if_lot_number_present(order_item, product, lot_number) : nil
  #   else
  #     @result['data']['serial']['product_lot_id'] = nil
  #   end
  # end

  def do_if_order_item_kit_product_present(params)
    item, child_item, _serial_added, clicked, order_item_kit_product, type_scan = params
    child_item_product_id = child_item['product_id']
    if child_item['record_serial']
      do_if_child_item_record_serial(params.push(child_item_product_id))
    else
      do_process_item(clicked, child_item_product_id, order_item_kit_product, item)
    end
  end

  def do_if_child_item_record_serial(params)
    item, child_item, serial_added, clicked, order_item_kit_product, type_scan, child_item_product_id = params
    if serial_added || type_scan
      set_serials_if_type_scan(order_item_kit_product.order_item, child_item_product_id, @typein_count) if type_scan
      do_process_item(clicked, child_item_product_id, order_item_kit_product, item)
    else
      @result['data']['serial']['ask'] = true
      @result['data']['serial']['product_id'] = child_item_product_id
    end
  end

  def do_process_item(clicked, child_item_product_id, order_item_kit_product, item)
    order_item_kit_product.process_item(clicked, @current_user.username, @typein_count, check_for_skip_settings(@input))
    @session[:most_recent_scanned_product] = child_item_product_id
    @session[:parent_order_item] = item['order_item_id']
  end

  def insert_in_box(item, kit_id)
    if @box_id.blank?
      box = Box.find_or_create_by(name: 'Box 1', order_id: item.order.id)
      @box_id = box.id
      order_item_box = OrderItemBox.where(order_item_id: item.id, box_id: @box_id, kit_id: kit_id).first
      if order_item_box.nil?
        OrderItemBox.create(order_item_id: item.id, box_id: box.id, item_qty: @typein_count, kit_id: kit_id)
      else
        if_order_item_present(item, kit_id)
      end
    else
      if_order_item_present(item, kit_id)
    end
  end

  def if_order_item_present(item, kit_id)
    box = Box.find_by_id(@box_id)
    if @single_order.id == box.order_id
      order_item_box = OrderItemBox.where(order_item_id: item.id, box_id: @box_id, kit_id: kit_id).first
      if order_item_box
        order_item_box.update_attributes(item_qty: order_item_box.item_qty + @typein_count)
      else
        OrderItemBox.create(order_item_id: item.id, box_id: @box_id, item_qty: @typein_count, kit_id: kit_id)
      end
    end
  end

  def remove_kit_item_from_order(child_item)
    order_item = OrderItem.where(id: child_item['order_item_id']).first
    if order_item
      order_item_kit_product = begin
                                 order_item.order_item_kit_products.find(child_item['kit_product_id'])
                               rescue StandardError
                                 nil
                               end
      end
    order_item_kit_product&.destroy
    order_item.destroy if order_item.order_item_kit_products.blank?
    child_item['product_qty_in_kit']
  end

  def should_remove_kit_item?(clean_input, child_item_skippable)
    check_for_skip_settings(clean_input) && child_item_skippable
  end
end
