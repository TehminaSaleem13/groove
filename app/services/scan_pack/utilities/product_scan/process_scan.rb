module ScanPack::Utilities::ProductScan::ProcessScan
  def process_scan(clicked, order_item, serial_added)
    @clicked, @order_item, @serial_added = clicked, order_item, serial_added
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
    if @serial_added
      @order_item.process_item(@clicked, @current_user.username, @typein_count, @box_id)
      insert_order_item_in_box if GeneralSetting.last.multi_box_shipments?
      @session[:most_recent_scanned_product] = @order_item.product_id
      @session[:parent_order_item] = false
      if @order_item.product.is_kit == 1
        @session[:parent_order_item] = @order_item.id
      end
    else 
      @result['data']['serial']['ask'] = @order_item.product.record_serial
      @result['data']['serial']['ask_2'] = @order_item.product.second_record_serial
      @result['data']['serial']['product_id'] = @order_item.product_id
    end
  end

  def insert_order_item_in_box
    if @box_id.blank?
      box = Box.find_or_create_by(:name => "Box 1", :order_id => @order_item.order.id)
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
end # module end
