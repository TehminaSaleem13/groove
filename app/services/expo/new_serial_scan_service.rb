# frozen_string_literal: true

module ScanPack
  class NewSerialScanService < ScanPack::Base
    include ScanPackHelper

    def initialize(current_user, session, params)
      set_scan_pack_action_instances(current_user, session, params)
      @order = Order.where(id: params[:order_id]).first
      @product = Product.where(id: params[:product_id]).first
    end

    def run
      serial_scan
      @result
    end

    def serial_scan
      serial_added = do_check_serial_added
      order_serial = do_find_or_create_order_serial

      if @params[:product_lot_id].present?
        do_if_product_lot_id_present(order_serial)
      else
        do_if_product_lot_id_not_present(order_serial)
        end
      should_scan_serial = begin
                               (!@params['scan_pack']['is_scan'] && @params['scan_pack']['ask'] && @params['scan_pack']['ask_2'])
                           rescue StandardError
                             (!@params['is_scan'] && @params['ask'] && @params['ask_2'])
                             end
      # if !@params["scan_pack"]["is_scan"] && @params["scan_pack"]["ask"] && @params["scan_pack"]["ask_2"]
      if should_scan_serial
        @order.addactivity("Product: \"#{@product.name}\" Serial scanned: \"#{@params[:serial]}\"", @current_user.name)
      else
        do_product_scan(serial_added)
      end
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
      if @params['second_serial']
        order_serials = OrderSerial.where(order_id: @order.id, product_id: @product.id)
        order_serials.last.update_attribute(:second_serial, @params[:serial])
      elsif @params['ask']
        order_serials = OrderSerial.where(order_id: @order.id, product_id: @product.id, serial: @params[:serial])
      else
        order_serials = OrderSerial.where(order_id: @order.id, product_id: @product.id, second_serial: @params[:serial])
      end
      order_serial = if order_serials.empty?
                       if @params['ask']
                         OrderSerial.create!(order_id: @order.id, product_id: @product.id, serial: @params[:serial])
                       else
                         OrderSerial.create!(order_id: @order.id, product_id: @product.id, second_serial: @params[:serial])
                       end
                     else
                       order_serials.first
                     end
    end

    def do_if_product_lot_id_not_present(order_serial)
      order_item_serial_lots = OrderItemOrderSerialProductLot.where(
        order_item_id: @params[:order_item_id], product_lot_id: @params[:product_lot_id],
        order_serial_id: order_serial.id
      )
      check_serial_lot = begin
                             !(@params['is_scan'] && @params['scan_pack']['ask'] && @params['scan_pack']['ask_2'])
                         rescue StandardError
                           (!(@params['is_scan'] && @params['ask'] && @params['ask_2']))
                           end
      # if !(@params["is_scan"] && @params["scan_pack"]["ask"] && @params["scan_pack"]["ask_2"])
      if check_serial_lot
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
      unless @params['clicked']
        count = begin
                    ProductBarcode.find_by_barcode(@params['barcode']).packing_count
                rescue StandardError
                  1
                  end
      end
      @order.addactivity(
        "Product: \"#{@product.name}\" Serial scanned: \"#{@params[:serial]}\"",
        @current_user.name
      )
      if @params['clicked']
        @result = product_scan(@params[:barcode], 'scanpack.rfp.default', @params[:order_id], @params[:box_id], @params[:on_ex], clicked: @params[:clicked], serial_added: serial_added, current_user: @current_user, session: @session)
      else
        @result = product_scan(@params[:barcode], 'scanpack.rfp.default', @params[:order_id], @params[:box_id], @params[:on_ex], clicked: @params[:clicked], serial_added: serial_added, current_user: @current_user, session: @session, typein_count: count.to_i)
      end

      @result
    end
  end
  end
