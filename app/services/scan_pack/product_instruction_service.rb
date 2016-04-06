module ScanPack
  class ProductInstructionService < ScanPack::Base
    def initialize(current_user, session, params)
      set_scan_pack_action_instances(current_user, session, params)
      @general_setting = GeneralSetting.all.first
      @order = Order.where(id: @params[:id]).first
    end

    def run
      product_instruction if params_and_data_valid && (
        !@general_setting.strict_cc || @current_user.confirmation_code == @params[:code]
        )
      @result
    end

    def params_and_data_valid
      id = @params[:id]
      code = @params[:code]

      if id.blank? || code.blank? || @params[:next_item].blank?
        set_error_messages('Order id, Item id and confirmation code required')
      elsif @order.blank?
        set_error_messages("Could not find order with id: #{id}")
      elsif @general_setting.strict_cc && @current_user.confirmation_code != code
        set_error_messages('Confirmation code doesn\'t match')
      end
      @result['status']
    end

    def product_instruction
      @order_item = OrderItem.where(id: @params[:next_item]['order_item_id']).first
      next_item = @params[:next_item]

      unless next_item['kit_product_id'].blank?
        @order_kit_product = OrderItemKitProduct.where(id: next_item['kit_product_id']).first
      end

      if do_check_valid_order_item_or_valid_kit_product(next_item)
        @order.addactivity("Item instruction scanned for product - #{next_item['name']}", @current_user.username)
      end

    end

    def do_check_valid_order_item_or_valid_kit_product(next_item)
      if @order_item.blank?
        set_error_messages('Couldnt find order item')
      elsif !next_item['kit_product_id'].blank? && (@order_kit_product.blank? ||
        @order_kit_product.order_item_id != @order_item.id)
        set_error_messages('Couldnt find child item')
      elsif @order_item.order_id != @order.id
        set_error_messages('Item doesnt belong to current order')
      end
      @result['status']
    end

  end
end