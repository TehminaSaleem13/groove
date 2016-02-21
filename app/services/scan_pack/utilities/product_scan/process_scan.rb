module ScanPack::Utilities::ProductScan::ProcessScan
  def process_scan(clicked, order_item, serial_added)
    @clicked, @order_item, @serial_added = clicked, order_item, serial_added
    do_if_order_item_present if @order_item.present?
    @result
  end

  def do_if_order_item_present
    if @order_item.product.record_serial
      do_if_record_serial_is_set
    else
      @order_item.process_item(@clicked, @current_user.username, @typein_count)
      (@session[:most_recent_scanned_products] ||= []) << @order_item.product_id
      @session[:parent_order_item] = @order_item.product.is_kit != 1 ? false : @order_item.id
    end
  end

  def do_if_record_serial_is_set
    if @serial_added
      @order_item.process_item(@clicked, @current_user.username, @typein_count)
      (@session[:most_recent_scanned_products] ||= []) << @order_item.product_id
      @session[:parent_order_item] = false
      if @order_item.product.is_kit == 1
        @session[:parent_order_item] = @order_item.id
      end
    else
      @result['data']['serial']['ask'] = true
      @result['data']['serial']['product_id'] = @order_item.product_id
    end
  end
end # module end