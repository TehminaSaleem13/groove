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
      @order = Order.where(id: params[:order_id]).first
      @product = Product.where(id: params[:product_id]).first
    end
  
    def run
      serial_scan if data_is_valid
      @result
    end

    def data_is_valid
      order_id = @params[:order_id]
      product_id = @params[:product_id]
      serial = @params[:serial]
      
      case true
      when !(order_id.present? && product_id.present?)
        set_error_messages('Order id and Product id are required')
      when !@order
        set_error_messages('Could not find order with id: '+order_id.to_s)
      when !@product
        set_error_messages('Could not find product with id: '+product_id.to_s)
      when barcode_found_or_special_code(serial)
        set_error_messages(
          "Product Serial number: #{serial} can not be the same as a "\
          "confirmation code, one of the action codes or any product barcode"
        )
      end
      
      @result['status']
    end

    def serial_scan
      serial_added = do_check_serial_added
      order_serial = do_find_or_create_order_serial

      unless @params[:product_lot_id].present?
        do_if_product_lot_id_not_present(order_serial)
      else
        do_if_product_lot_id_present(order_serial)
      end

      do_product_scan(serial_added)
    end

    def do_check_serial_added
      if @params[:serial].blank?
        @params[:serial] = 'N/A'
        false
      else
        true
      end
    end

    def do_find_or_create_order_serial
      order_serials = OrderSerial.where(
        order_id: @order.id, product_id: @product.id, serial: @params[:serial]
      )
      
      order_serial =  unless order_serials.empty?
        order_serials.first
      else
        OrderSerial.create!(
          order_id: @order.id, product_id: @product.id,
          serial: @params[:serial]
        )
      end
    end

    def do_if_product_lot_id_not_present(order_serial)
      order_item_serial_lots = OrderItemOrderSerialProductLot.where(
        order_item_id: @params[:order_item_id], product_lot_id: @params[:product_lot_id],
        order_serial_id: order_serial.id
      )
      
      if order_item_serial_lots.empty?
        OrderItemOrderSerialProductLot.create!(
          order_item_id: @params[:order_item_id], product_lot_id: @params[:product_lot_id],
          order_serial_id: order_serial.id, qty: 1
        )
      else
        existing_serial = order_item_serial_lots.first
        existing_serial.qty += 1
        existing_serial.save
      end
    end

    def do_if_product_lot_id_present(order_serial)
      order_item_serial_lots = OrderItemOrderSerialProductLot.where(
        order_item_id: @params[:order_item_id], product_lot_id: @params[:product_lot_id]
        )
      
      unless order_item_serial_lots.empty?
        existing_serials = order_item_serial_lots.where(order_serial_id: order_serial.id)
        if existing_serials.empty?
          new_serial = order_item_serial_lots.where(order_serial_id: nil).first ||
                        order_item_serial_lots.create(order_serial_id: nil)
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

    def do_product_scan(serial_added)
      @result = product_scan(
        @params[:barcode], 'scanpack.rfp.default', @params[:order_id],
        {
          clicked: @params[:clicked], serial_added: serial_added,
          current_user: @current_user, session: @session
        }
      )
      
      @order.addactivity(
        "Product: \"#{@product.name.to_s}\" Serial scanned: \"#{@params[:serial].to_s}\"",
        @current_user.name
      )
      
      @result
    end

  end
end