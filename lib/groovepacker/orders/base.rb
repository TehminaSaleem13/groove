# frozen_string_literal: true

module Groovepacker
  module Orders
    class Base
      include ProductsHelper
      include Groovepacker::Orders::ResponseMessage

      def initialize(params = {})
        @result = params[:result]
        @params = params[:params_attrs]
        @current_user = params[:current_user]
        @platform = params[:params_attrs].try(:[], :on_ex)
      end

      private

      def supported_sort_keys
        %w[updated_at notes ordernum order_date itemslength recipient
           status email tracking_num city state postcode country
           custom_field_one custom_field_two store_name last_modified tote]
       end

      def supported_order_keys
        %w[ASC DESC] # Caps letters only
      end

      def supported_status_filters
        %w[all awaiting partially_scanned onhold cancelled scanned serviceissue]
      end

      def get(attribute, default_value)
        return_val = nil
        hash = { 'sort_key' => 'sort', 'sort_order' => 'order', 'status_filter' => 'filter' }
        supported = { 'sort_keys' => supported_sort_keys, 'sort_orders' => supported_order_keys, 'status_filters' => supported_status_filters }

        if @params[hash[attribute]].present? && supported[attribute.pluralize].include?(@params[hash[attribute]])
          return_val = @params[hash[attribute]]
        end
        return_val || default_value
      end

      def get_limit_or_offset(type)
        return_val = type == 'limit' ? 10 : 0
        comp_val = type == 'limit' ? 1 : 0

        return_val = @params[type].to_i if @params[type].present? && @params[type].to_i >= comp_val
      end

      def set_final_sort_key(sort_order, sort_key)
        return 'updated_at' if @params[:app] && @params[:oldest_unscanned] != 'true'

        sort_key_hash = { 'ordernum' => 'increment_id', 'order_date' => 'order_placed_time', 'notes' => 'notes_internal', 'recipient' => "firstname #{sort_order}, lastname", 'store_name' => 'store_name' }
        sort_key = sort_key_hash[sort_key] if sort_key_hash.key?(sort_key)
        sort_key
      end

      def get_query_limit_offset(limit, offset)
        query_add = nil
        query_add = " LIMIT #{limit} OFFSET #{offset}" unless @params[:select_all] || @params[:inverted]
        query_add ||= ''
      end

      def row_map
        { quantity: '',
          product_name: '',
          primary_sku: '',
          primary_barcode: '',
          primary_barcode_qty: '',
          secondary_barcode: '',
          secondary_barcode_qty: '',
          tertiary_barcode: '',
          tertiary_barcode_qty: '',
          quaternary_barcode: '',
          quaternary_barcode_qty: '',
          quinary_barcode: '',
          quinary_barcode_qty: '',
          senary_barcode: '',
          senary_barcode_qty: '',
          location_primary: '',
          location_secondary: '',
          location_tertiary: '',
          image_url: '',
          available_inventory: '',
          product_status: '',
          order_number: '' }
      end

      def order_export_row_map
        export_row_map = {
          order_number: '',
          store_name: '',
          order_date_time: '',
          sku: '',
          product_name: '',
          barcode: '',
          qty: '',
          first_name: '',
          last_name: '',
          email: '',
          address_1: '',
          address_2: '',
          city: '',
          state: '',
          postal_code: '',
          country: '',
          customer_comments: '',
          internal_notes: '',
          tags: '',
          tracking_num: '',
          scanned_count: '',
          unscanned_count: '',
          removed_count: '',
          scanning_user: ''
        }

        if @current_workflow == 'product_first_scan_to_put_wall'
          export_row_map = export_row_map.merge(
            order_num: '',
            sku: '',
            tote: '',
            qty_remaining: '',
            qty_in_tote: '',
            qty_ordered: ''
          )
        end
        export_row_map = export_row_map.merge(@general_settings.custom_field_one.parameterize.underscore.to_sym => '') if @general_settings.custom_field_one
        export_row_map = export_row_map.merge(@general_settings.custom_field_two.parameterize.underscore.to_sym => '') if @general_settings.custom_field_two
        export_row_map
      end

      def get_context(store)
        case store.store_type
        when 'Amazon'
          handler = Groovepacker::Stores::Handlers::AmazonHandler.new(store)
        when 'Ebay'
          handler = Groovepacker::Stores::Handlers::EbayHandler.new(store)
        when 'Magento'
          handler = Groovepacker::Stores::Handlers::MagentoHandler.new(store)
        when 'Shipstation'
          handler = Groovepacker::Stores::Handlers::ShipstationHandler.new(store)
        when 'Shipstation API 2'
          handler = Groovepacker::Stores::Handlers::ShipstationRestHandler.new(store)
        when 'Shopify'
          handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(store)
        when 'BigCommerce'
          handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(store)
        end
        context = Groovepacker::Stores::Context.new(handler)
      end

      def get_filename
        'groove-order-items-' + Apartment::Tenant.current + '-' + Time.current.strftime('%d_%b_%Y_%H_%M_%S_%Z') + '.csv'
      end

      def accepted_data
        {
          'ordernum' => 'increment_id',
          'order_date' => 'order_placed_time',
          'recipient' => 1,
          'notes' => 'notes_internal',
          'notes_from_packer' => 'notes_fromPacker',
          'status' => 'status',
          'email' => 'email',
          'tracking_num' => 'tracking_num',
          'city' => 'city',
          'state' => 'state',
          'postcode' => 'postcode',
          'country' => 'country',
          'custom_field_one' => 'custom_field_one',
          'custom_field_two' => 'custom_field_two'
        }
      end
    end
  end
end
