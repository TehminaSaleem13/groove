# frozen_string_literal: true

module ScanPack::Utilities::ProductScan::ProcessScan
  def process_scan(clicked, order_item, serial_added, type_scan = false)
    @clicked = clicked
    @order_item = order_item
    @serial_added = serial_added
    @type_scan = type_scan
    do_if_order_item_present if @order_item.present?
    @result
  end

  def do_if_order_item_present
    if @order_item.product.record_serial || @order_item.product.second_record_serial
      do_if_record_serial_is_set
    else
      @order_item.process_item(@clicked, @current_user.username, @typein_count, @box_id)
      insert_order_item_in_box if GeneralSetting.last.multi_box_shipments?
      @session[:most_recent_scanned_product] = @order_item.product_id
      @session[:parent_order_item] = @order_item.product.is_kit != 1 ? false : @order_item.id
    end
  end

  def do_if_record_serial_is_set
    if @serial_added || @type_scan
      set_serials_if_type_scan(@order_item, @order_item.product.id, @typein_count) if @type_scan
      @order_item.process_item(@clicked, @current_user.username, @typein_count, @box_id)
      insert_order_item_in_box if GeneralSetting.last.multi_box_shipments?
      @session[:most_recent_scanned_product] = @order_item.product_id
      @session[:parent_order_item] = false
      @session[:parent_order_item] = @order_item.id if @order_item.product.is_kit == 1
    else
      @result['data']['serial']['ask'] = @order_item.product.record_serial
      @result['data']['serial']['ask_2'] = @order_item.product.second_record_serial
      @result['data']['serial']['product_id'] = @order_item.product_id
    end
  end

  def insert_order_item_in_box
    if @box_id.blank?
      box = Box.find_or_create_by(name: 'Box 1', order_id: @order_item.order.id)
      @box_id = box.id
      order_item_box = OrderItemBox.where(order_item_id: @order_item.id, box_id: @box_id).first
      if order_item_box.nil?
        OrderItemBox.create(order_item_id: @order_item.id, box_id: box.id, item_qty: @typein_count)
      else
        if_order_item
      end
    else
      if_order_item
    end
  end

  def if_order_item
    box = Box.find_by_id(@box_id)
    if @single_order.id == box.order_id
      order_item_box = OrderItemBox.where(order_item_id: @order_item.id, box_id: @box_id).first
      if order_item_box
        order_item_box.update_attributes(item_qty: order_item_box.item_qty + @typein_count)
      else
        OrderItemBox.create(order_item_id: @order_item.id, box_id: @box_id, item_qty: @typein_count)
      end
    end
  end

  def set_serials_if_type_scan(order_item, product_id, count)
    order_serial = OrderSerial.where(order_id: order_item.order.id, product_id: product_id).first
    order_item_serial_lots = OrderItemOrderSerialProductLot.where(
      order_item_id: order_item.id,
      order_serial_id: order_serial.id
    )

    if order_item_serial_lots.empty?
      OrderItemOrderSerialProductLot.create!(
        order_item_id: order_item.id,
        order_serial_id: order_serial.id, qty: count
      )
    else
      existing_serial = order_item_serial_lots.last
      existing_serial.qty += count
      existing_serial.save
    end
  rescue StandardError => e
    puts "==Serial Scan Error\n#{e.message}\n"
  end
end
