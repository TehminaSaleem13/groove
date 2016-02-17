module ScanPack
  class SerialScanService < ScanPack::Base
    include ScanPackHelper
    
    def initialize(current_user, session, params)
      @current_user = current_user
      @params = params
      @session = session
      @result = {
        "status" => true, "error_messages" => [], "success_messages" => [],
        "notice_messages" => [], 'data' => {}
      }
    end
  
    def run
      serial_scan if data_is_valid
      @result
    end

    def data_is_valid
      case true
      when !(@params[:order_id].present? && @params[:product_id].present?)
        set_error_messages('Order id and Product id are required')
      when !(@order = Order.where(id: @params[:order_id]).first)
        set_error_messages('Could not find order with id: '+@params[:order_id].to_s)
      when !(@product = Product.where(id: @params[:product_id]).first)
        set_error_messages('Could not find product with id: '+@params[:product_id].to_s)
      when barcode_found_or_special_code(@params[:serial])
        set_error_messages(
          "Product Serial number: #{@params[:serial]} can not be the same as a "\
          "confirmation code, one of the action codes or any product barcode"
        )
      end
      @result['status']
    end

    def serial_scan
      serial_added = true
      if @params[:serial].blank?
        @params[:serial] = 'N/A'
        serial_added = false
      end
      
      
      order_serials = OrderSerial.where(order_id: @order.id, product_id: @product.id, serial: @params[:serial])
      unless order_serials.empty?
        order_serial = order_serials.first
      else
        order_serial = OrderSerial.new
        order_serial.order = @order
        order_serial.product = @product
        order_serial.serial = @params[:serial]
        order_serial.save
      end

      if @params[:product_lot_id].nil?
        order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: @params[:order_item_id], product_lot_id: @params[:product_lot_id], order_serial_id: order_serial.id)
        if order_item_serial_lots.empty?
          OrderItemOrderSerialProductLot.create(order_item_id: @params[:order_item_id], product_lot_id: @params[:product_lot_id], order_serial_id: order_serial.id, qty: 1)
        else
          existing_serial = order_item_serial_lots.first
          existing_serial.qty += 1
          existing_serial.save
        end
      else
        order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: @params[:order_item_id], product_lot_id: @params[:product_lot_id])
        unless order_item_serial_lots.empty?
          existing_serials = order_item_serial_lots.where(order_serial_id: order_serial.id)
          if existing_serials.empty?
            new_serial = order_item_serial_lots.where(order_serial_id: nil).first || order_item_serial_lots.create(order_serial_id: nil)
            new_serial.order_serial = order_serial
            new_serial.save
          else
            order_item_serial_lots.where(order_serial_id: nil).first.try :destroy
            existing_serial = existing_serials.first
            existing_serial.qty += 1
            existing_serial.save
          end
        end
      end
      @result = product_scan(
        @params[:barcode], 'scanpack.rfp.default', @params[:order_id],
        {clicked: @params[:clicked], serial_added: serial_added, current_user: @current_user, session: @session}
        )
      @order.addactivity('Product: "'+@product.name.to_s+'" Serial scanned: "'+@params[:serial].to_s+'"', @current_user.name)
      
      @result
    end

  end
end