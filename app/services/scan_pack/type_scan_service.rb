module ScanPack
  class TypeScanService < ScanPack::Base
    include ScanPackHelper

    def initialize(current_user, session, params)
      set_scan_pack_action_instances(current_user, session, params)
      @order = Order.where(id: @params[:id]).first
    end

    def run
      type_scan if valid_params_and_data
      @result
    end

    def valid_params_and_data
      if @params[:id].blank? || @params[:count].to_i < 1 || @params[:next_item].blank?
        set_error_messages('Order id, Item id and Type-in count are required')
      elsif !@order
        set_error_messages("Could not find order with id: #{@params[:id].to_s}")
      end
      @result['status']
    end

    def type_scan
      next_item = @params[:next_item]
      return unless do_check_valid_order_item_or_valid_kit_product(next_item)

      barcodes = next_item[:barcodes]
      first_barcode = barcodes[0]

      unless barcodes.blank? || first_barcode.blank? || first_barcode[:barcode].blank?
        @result['data'] = product_scan(
            first_barcode[:barcode], 'scanpack.rfp.default', @params[:id],
            {
              clicked: false, serial_added: false, typein_count: @params[:count].to_i,
              current_user: @current_user, session: @session
            }
          )
        @order.addactivity("Type-In count Scanned for product #{next_item[:sku].to_s}", @current_user.username)
      end

    end

    def do_check_valid_order_item_or_valid_kit_product(next_item)
      kit_product_id = next_item['kit_product_id']

      do_get_order_item_and_kit_product(next_item, kit_product_id)

      if @order_item.blank?
        set_error_messages('Couldnt find order item')
      elsif !kit_product_id.blank? && (@order_kit_product.blank? ||
        @order_kit_product.order_item_id != @order_item.id)
        set_error_messages('Couldnt find child item')
      elsif @order_item.order_id != @order.id
        set_error_messages('Item doesnt belong to current order')
      elsif @params[:count] > next_item[:qty]
        set_error_messages('Wrong count has been entered. Please try again')
      end

      @result['status']
    end

    def do_get_order_item_and_kit_product(next_item, kit_product_id)
      @order_item = OrderItem.where(id: next_item['order_item_id']).first

      unless kit_product_id.blank?
        @order_kit_product = OrderItemKitProduct.where(id: kit_product_id).first
      end
    end

  end
end
