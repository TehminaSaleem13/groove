module SettingsService
  class OrderSerialExport < SettingsService::Base
    attr_reader :current_user, :params, :result, :row_map, :serials
    attr_writer :result

    include SettingsService::Utils

    def initialize(current_user: nil, params: nil)
      @current_user = current_user
      @params = params
      @result = {
        'status' => true,
        'messages' => [],
        'data' => nil,
        'filename' => "groove-order-serials-#{Time.now}.csv"
      }
      @row_map = {
        order_date: '', order_number: '', serial: '', primary_sku: '',
        primary_barcode: '', product_name: '', item_sale_price: '',
        kit_name: '', scan_order: 0, customer_name: '', address1: '',
        address2: '', city: '', state: '', zip: '', packing_user: '',
        order_item_count: '', scanned_date: '', warehouse_name: ''
      }
      @serials = OrderSerial.where(updated_at:
        Time.parse(params[:start])..Time.parse(params[:end])
      )
    end

    def call
      validate_params
      if current_user.can? 'view_packing_ex'
        generate_csv
      else
        result['status'] = false
        result['messages'].push('You do not have enough permissions to view order serials')
      end

      do_if_status_false
      super
    end

    private

    def generate_csv
      result['data'] = CSV.generate do |csv|
        csv << row_map.keys
        order_number = ''
        scan_order = 0
        serials.each do |serial|
          single_row = row_map.dup
          order_number,
          scan_order = update_scan_order_and_order_number(
            serial, order_number, scan_order
          )
          generate_single_record(serial, single_row)
          csv << single_row.values
        end
      end
    end

    def update_scan_order_and_order_number(serial, order_number, scan_order)
      if order_number == serial.order.increment_id
        scan_order += 1
      else
        order_number = serial.order.increment_id
        scan_order = 1
      end
      [order_number, scan_order]
    end

    def generate_single_record(serial, single_row)
      order = serial.order
      product = serial.product

      push_order_data(single_row, order)
      push_user_data(single_row, order, product)
      push_product_data(single_row, product, order, serial)

      # item sale price
      order_items = order.order_items.where(product_id: product.id)
      if order_items.empty?
        single_row[:item_sale_price] = ''
      else
        single_row[:item_sale_price] = order_items.first.price
      end
    end

    def push_order_data(single_row, order)
      single_row[:scan_order],
      single_row[:order_number],
      single_row[:order_date],
      single_row[:scanned_date],
      single_row[:address1],
      single_row[:address2],
      single_row[:city],
      single_row[:state],
      single_row[:zip],
      single_row[:order_item_count] = order.as_json(
        only: [
          :scan_order, :increment_id, :order_placed_time, :scanned_on,
          :address_1, :address_2, :city, :state, :postcode
        ],
        methods: :get_items_count
      ).values
    end

    def push_user_data(single_row, order, product)
      packing_user = User.where(id: order.packing_user_id).first
      return unless packing_user
      single_row[:packing_user] = "#{packing_user.name} (#{packing_user.username})"
      single_row[:warehouse_name] = product.primary_warehouse
                                    .try(:inventory_warehouse).try(:name)
    end

    def push_product_data(single_row, product, order, serial)
      single_row[:serial] = serial.serial
      if product.is_kit == 1
        single_row[:kit_name] = product.name
      else
        single_row[:product_name] = product.name
      end
      single_row[:customer_name] = [order.firstname, order.lastname].join(' ')
      single_row[:primary_sku] = product.primary_sku
      single_row[:primary_barcode] = product.primary_barcode
    end
  end
end
