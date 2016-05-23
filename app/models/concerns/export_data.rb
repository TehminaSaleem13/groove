module ExportData
  extend ActiveSupport::Concern

  private

  def generate_header
    YAML.load_file('config/data_mappings/export_data_header.yml')
  end

  # def set_result_hash
  #   {
  #     'status' => true,
  #     'messages' => []
  #   }
  # end

  def export_if_order_with_serial_lot(order_item, row_map, order_hash_item_array)
    order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: order_item.id)
    return if order_item_serial_lots.empty?
    order_item_serial_lots.each do |order_item_serial_lot|
      product_lot = order_item_serial_lot.product_lot
      order_serial = order_item_serial_lot.order_serial
      next unless order_serial && product_lot
      parse_order_item_serial_lots([
        order_item_serial_lot, row_map, order_item,
        product_lot, order_serial, order_hash_item_array
      ])
    end
  end

  def parse_order_item_serial_lots(m_params)
    order_item_serial_lot, row_map, order_item,
    product_lot, order_serial, order_hash_item_array = m_params
    (1..order_item_serial_lot.qty).each do
      single_row = row_map.dup
      single_row = calculate_row_data(single_row, order_item)
      single_row[:order_item_count] = 1
      set_lot_number_and_barcode_with_lot(single_row, order_item, product_lot)
      process_order_serial(single_row, order_serial, order_item)
      order_hash_item_array.push(single_row.dup)
    end
  end

  def set_lot_number_and_barcode_with_lot(single_row, order_item, product_lot)
    if product_lot.nil?
      single_row[:lot_number] = ''
      single_row[:barcode_with_lot] = ''
    else
      lot_number = product_lot.lot_number
      single_row[:lot_number] = lot_number
      single_row[:barcode_with_lot] = order_item.get_barcode_with_lotnumber(
        order_item.product.primary_barcode, lot_number
      ) if lot_number.present?
    end
  end

  def process_order_serial(single_row, order_serial, order_item)
    return '' if order_serial.blank?
    fetch_product_data(single_row, order_serial, order_item)
    single_row[:serial_number] = order_serial.serial
    calculate_scan_order(single_row, order_serial, order_item)
  end

  def fetch_product_data(single_row, order_serial, order_item)
    order_serial_product = order_serial.product
    return unless order_serial_product.is_kit == 0 && order_item.product.is_kit == 1
    single_row[:part_sku] = order_serial_product.primary_sku
    single_row[:product_name] = order_serial_product.name
    single_row[:item_sale_price] = order_serial_product.order_items
                                   .try(:first).try(:price).to_f
  end

  def calculate_scan_order(single_row, order_serial, order_item)
    serials = OrderSerial.where(order_id: order_item.order.id)
    single_row[:scan_order] = 1 + serials.index do |serial|
      serial.serial == order_serial.serial
    end
  end

  def export_without_order_with_serial_lot(order_item, row_map, order_hash_item_array)
    order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: order_item.id)
    if order_item_serial_lots.empty?
      single_row = do_if_serial_lots_empty(row_map, order_item)
      order_hash_item_array.push(single_row.dup)
    else
      qty_with_lot_serial = 0
      order_item_serial_lots.each do |order_item_serial_lot|
        single_row = process_order_item_serial_lots(order_item_serial_lot, row_map, order_item, qty_with_lot_serial)
        order_hash_item_array.push(single_row.dup)
      end
      if order_item.qty > qty_with_lot_serial
        single_row = do_if_qty_greater_than_qty_with_lot_setial(
          row_map, order_item,
          qty_with_lot_serial
        )
        order_hash_item_array.push(single_row.dup)
      end
    end
  end

  def do_if_serial_lots_empty(row_map, order_item)
    single_row = row_map.dup
    single_row = calculate_row_data(single_row, order_item)
    single_row[:order_item_count] = order_item.qty
    single_row[:lot_number] = ''
    single_row[:barcode_with_lot] = ''
    single_row[:serial_number] = ''
    single_row[:scan_order] = ''
    single_row
  end

  def do_if_qty_greater_than_qty_with_lot_setial(row_map, order_item, qty_with_lot_serial)
    single_row = row_map.dup
    single_row = calculate_row_data(single_row, order_item)
    single_row[:order_item_count] = order_item.qty - qty_with_lot_serial
    single_row[:lot_number] = ''
    single_row[:barcode_with_lot] = ''
    single_row[:serial_number] = ''
    single_row[:scan_order] = ''
    single_row
  end

  def process_order_item_serial_lots(order_item_serial_lot, row_map, order_item, qty_with_lot_serial)
    product_lot = order_item_serial_lot.product_lot unless order_item_serial_lot.product_lot.nil?
    order_serial = order_item_serial_lot.order_serial unless order_item_serial_lot.order_serial.nil?
    single_row = row_map.dup
    single_row = calculate_row_data(single_row, order_item)
    single_row[:order_item_count] = order_item_serial_lot.qty
    qty_with_lot_serial += order_item_serial_lot.qty

    set_lot_number_and_barcode_with_lot(single_row, order_item, product_lot)

    process_order_serial(single_row, order_serial, order_item)
    single_row
  end

  def do_export_with_orders(orders, filename)
    row_map = generate_default_row_map
    order_hash_array = []
    order_hash = generate_header
    order_hash_array.push(order_hash)
    fetch_orders_hash_array(orders, row_map, order_hash_array)
    push_orders_hash_array_to_csv_file(filename, order_hash_array, row_map)
  end

  def generate_default_row_map
    generate_header.reduce({}){|h, (k, v)| h[k] = ''; h}
  end

  def sort_by_scan_order(order_hash_item_array)
    order_hash_item_array.sort_by! { |hsh| hsh[:scan_order].to_i }
  end

  def push_orders_to_array(order_hash_array, order_hash_item_array)
    order_hash_item_array.each { |hsh| order_hash_array.push(hsh) }
  end

  def generate_csv_row_map(show_serial_number, show_lot_number, row_map)
    if show_serial_number == false && show_lot_number == false
      row_map.except(
        :scan_order, :barcode_with_lot, :lot_number,
        :part_sku, :serial_number
      )
    elsif show_serial_number == false && show_lot_number == true
      row_map.except(:scan_order, :serial_number)
    elsif show_serial_number == true && show_lot_number == false
      row_map.except(:barcode_with_lot, :lot_number)
    else
      row_map
    end
  end

  def show_lot_or_serial_number?(order_hash_array, key)
    show = false
    (1..order_hash_array.size - 1).each do |i|
      unless order_hash_array[i][key].nil? || order_hash_array[i][key] == ''
        show = true
        break
      end
    end
    show
  end

  def fetch_orders_hash_array(orders, row_map, order_hash_array)
    orders.each do |order|
      order_items = order.order_items
      next if order_items.empty?
      order_hash_item_array = []
      order_items.each do |order_item|
        if order_export_type == 'order_with_serial_lot'
          export_if_order_with_serial_lot(order_item, row_map, order_hash_item_array)
        else
          export_without_order_with_serial_lot(order_item, row_map, order_hash_item_array)
        end
      end
      sort_by_scan_order(order_hash_item_array)
      push_orders_to_array(order_hash_array, order_hash_item_array)
    end
  end

  def push_orders_hash_array_to_csv_file(filename, order_hash_array, row_map)
    CSV.open("#{Rails.root}/public/csv/#{filename}", 'w') do |csv|
      show_lot_number = show_lot_or_serial_number?(order_hash_array, :lot_number)
      show_serial_number = show_lot_or_serial_number?(order_hash_array, :serial_number)

      csv_row_map = generate_csv_row_map(show_serial_number, show_lot_number, row_map)

      order_hash_array.each do |order_hash|
        csv << order_hash.values_at(*csv_row_map.keys)
      end
    end
  end
end
