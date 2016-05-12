module Groovepacker
  module Orders
    class Base
      include ProductsHelper
      include Groovepacker::Orders::ResponseMessage

      def initialize(params={})
        @result = params[:result]
        @params = params[:params_attrs]
        @current_user = params[:current_user]
      end

      private
      	def supported_sort_keys
          [ 'updated_at', 'notes', 'ordernum', 'order_date', 'itemslength', 'recipient',
            'status', 'email', 'tracking_num', 'city', 'state', 'postcode', 'country',
            'custom_field_one', 'custom_field_two']
        end

        def supported_order_keys
          ['ASC', 'DESC'] #Caps letters only
        end

        def supported_status_filters
          ['all', 'awaiting', 'onhold', 'cancelled', 'scanned', 'serviceissue']
        end

        def get(attribute, default_value)
          return_val = nil
          hash = {'sort_key' => 'sort', 'sort_order' => 'order', 'status_filter' => 'filter'}
          supported = {'sort_keys' => supported_sort_keys, 'sort_orders' => supported_order_keys, 'status_filters' => supported_status_filters}

          if @params[hash[attribute]].present? && supported[attribute.pluralize].include?(@params[hash[attribute]])
            return_val = @params[hash[attribute]]
          end
          return return_val || default_value
        end

        def get_limit_or_offset(type)
          return_val = type=='limit' ? 10 : 0
          comp_val = type=='limit' ? 1 : 0

          return_val = @params[type].to_i if @params[type].present? && @params[type].to_i >= comp_val
        end

        def set_final_sort_key(sort_order, sort_key)
          sort_key_hash = {'ordernum' => 'increment_id', 'order_date' => 'order_placed_time', 'notes' => 'notes_toPacker', 'recipient' => "firstname #{sort_order}, lastname"}
          sort_key = sort_key_hash[sort_key] if sort_key_hash.keys.include?(sort_key)
          return sort_key
        end

        def get_query_limit_offset(limit, offset)
          query_add = nil
          unless @params[:select_all] || @params[:inverted]
            query_add = " LIMIT #{limit} OFFSET #{offset}"
          end
          query_add ||= ""
        end

        def row_map
          return {:quantity => '',
                  :product_name => '',
                  :primary_sku => '',
                  :primary_barcode => '',
                  :secondary_barcode => '',
                  :tertiary_barcode => '',
                  :location_primary => '',
                  :location_secondary => '',
                  :location_tertiary => '',
                  :image_url => '',
                  :available_inventory => '',
                  :product_status => '',
                  :order_number => '',
                }
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
          return 'groove-order-items-'+Apartment::Tenant.current+'-'+Time.now.strftime('%d_%b_%Y_%H_%M_%S_%Z')+'.csv'
        end

        def accepted_data
          return {
            "ordernum" => "increment_id",
            "order_date" => "order_placed_time",
            "recipient" => 1,
            "notes" => "notes_internal",
            "notes_from_packer" => "notes_fromPacker",
            "status" => "status",
            "email" => "email",
            "tracking_num" => "tracking_num",
            "city" => "city",
            "state" => "state",
            "postcode" => "postcode",
            "country" => "country",
            "custom_field_one" => "custom_field_one",
            "custom_field_two" => "custom_field_two"
          }
        end
    end
  end
end
