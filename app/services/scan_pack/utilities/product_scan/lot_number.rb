# frozen_string_literal: true

module ScanPack::Utilities::ProductScan::LotNumber
  def calculate_lot_number
    # escape_string = @scanpack_settings.escape_string_enabled && @scanpack_settings.escape_string
    # if escape_string && !@input.index(escape_string).nil?
    #   return @input.slice(
    #     (@input.index(escape_string) + escape_string.length)..(@input.length-1)
    #   )
    # end
    if @scanpack_settings.escape_string_enabled
      first_escape_string = @scanpack_settings.escape_string
      second_escape_string = @scanpack_settings.second_escape_string
      first_escape = @scanpack_settings.first_escape_string_enabled && first_escape_string.present? && !@input.index(first_escape_string || '').nil?
      second_escape = @scanpack_settings.second_escape_string_enabled && second_escape_string.present? && !@input.index(second_escape_string || '').nil?
      if first_escape && second_escape
        clean_input = @input.split(first_escape_string).last.split(second_escape_string).last
      elsif first_escape
        clean_input = @input.split(first_escape_string).last
      elsif second_escape
        clean_input = @input.split(second_escape_string).last
      end
    end
    clean_input
  end

  def store_lot_number(order_item, serial_added)
    unless serial_added
      do_if_record_lot_number_is_set_and_serial_added_is_not_set(
        order_item
      )
    end
    @result
  end

  def do_if_record_lot_number_is_set_and_serial_added_is_not_set(order_item)
    product = order_item.product
    lot_number = calculate_lot_number
    @result['data']['serial']['order_item_id'] = order_item.id
    @result['data']['serial']['product_lot_id'] = lot_number.present? ?
                                                  do_if_lot_number_present(order_item, product, lot_number) : nil
  end

  def do_if_lot_number_present(order_item, product, lot_number)
    product_lots = product.product_lots
    product_lot = product_lots.where(lot_number: lot_number).first || product_lots.create(lot_number: lot_number)
    OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
    product_lot.id
  end
end # module end
