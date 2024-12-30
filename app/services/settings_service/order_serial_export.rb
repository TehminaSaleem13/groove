# frozen_string_literal: true

module SettingsService
  class OrderSerialExport < SettingsService::Base
    attr_accessor :result
    attr_reader :current_user, :params, :row_map, :serials

    include SettingsService::Utils

    def initialize(current_user: nil, params: nil)
      @current_user = current_user
      @params = params
      @result = {
        'status' => true,
        'messages' => [],
        'data' => nil,
        'filename' => "groove-order-serials-#{Time.current}.csv"
      }
      @row_map = {
        order_date: '', order_number: '', serial: '', primary_sku: '',
        primary_barcode: '', product_name: '', item_sale_price: '',
        kit_name: '', scan_order: 0, customer_name: '', address1: '',
        address2: '', city: '', state: '', zip: '', packing_user: '',
        ordered_qty: '', scanned_date: '', warehouse_name: '', lot: '', exp_date: '', bestbuy_date: '', mfg_date: ''
      }
      @serials = OrderSerial.includes({ order: %i[packing_user],
                                        product: %i[product_skus product_barcodes
                                                    product_inventory_warehousess] }).where(updated_at: Time.zone.parse(params[:start])..Time.zone.parse(params[:end]))
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
      data = CSV.generate do |csv|
        csv << row_map.keys
        order_number = ''
        scan_order = 0
        serials.each do |serial|
          single_row = row_map.dup
          order_number,
          scan_order = update_scan_order_and_order_number(
            serial, order_number, scan_order
          )
          generate_single_record(serial, single_row, scan_order)
          csv << single_row.values
        end
      end

      public_url = GroovS3.create_public_csv(Apartment::Tenant.current, 'groove-order-serials', Time.current.to_s, data).url.gsub(
        'http:', 'https:'
      )
      @result[:filename] = { url: public_url, filename: @result['filename'] }
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

    def generate_single_record(serial, single_row, scan_order)
      order = serial.order
      product = serial.product
      return if product.nil?

      push_order_data(single_row, order, scan_order)
      push_user_data(single_row, order, product)
      push_product_data(single_row, product, order, serial)

      # item sale price
      order_items = order.order_items.where(product_id: product.id)
      single_row[:item_sale_price] = if order_items.empty?
                                       ''
                                     else
                                       order_items.first.price
                                     end
    end

    def push_order_data(single_row, order, scan_order)
      single_row[:scan_order] = scan_order
      single_row[:order_number] = order.increment_id
      single_row[:order_date] = order.order_placed_time
      single_row[:scanned_date] = order.scanned_on
      single_row[:address1] = order.address_1
      single_row[:address2] = order.address_2
      single_row[:city] = order.city
      single_row[:state] = order.state
      single_row[:zip] = order.postcode
      single_row[:ordered_qty] = order.get_items_count
    end

    def push_user_data(single_row, order, product)
      packing_user = order.packing_user
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
      single_row[:lot] = serial.lot
      single_row[:exp_date] = serial.exp_date
      single_row[:bestbuy_date] = serial.bestbuy_date
      single_row[:mfg_date] = serial.mfg_date
    end
  end
end
