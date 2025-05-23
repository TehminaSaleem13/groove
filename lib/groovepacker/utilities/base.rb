# frozen_string_literal: true

module Groovepacker
  module Utilities
    class Base
      require 'import_orders'
      attr_accessor :import_params
      include ::AhoyEvent

      def initialize(params = {})
        self.import_params = params
      end

      def init_import(tenant)
        Apartment::Tenant.switch!(tenant)
      end

      def get_handler(store_type, store, import_item)
        case store_type
        when 'Amazon'
          handler = Groovepacker::Stores::Handlers::AmazonHandler.new(store, import_item)
        when 'Ebay'
          handler = Groovepacker::Stores::Handlers::EbayHandler.new(store, import_item)
        when 'Magento'
          handler = Groovepacker::Stores::Handlers::MagentoHandler.new(store, import_item)
        when 'Magento API 2'
          handler = Groovepacker::Stores::Handlers::MagentoRestHandler.new(store, import_item)
        when 'Shipstation'
          handler = Groovepacker::Stores::Handlers::ShipstationHandler.new(store, import_item)
        when 'Shippo'
          handler = Groovepacker::Stores::Handlers::ShippoHandler.new(store,import_item)
        when 'Shipstation API 2'
          handler = Groovepacker::Stores::Handlers::ShipstationRestHandler.new(store, import_item)
        when 'ShippingEasy'
          handler = Groovepacker::Stores::Handlers::ShippingEasyHandler.new(store, import_item)
        when 'Shopify'
          handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(store, import_item)
        when 'Shopline'
          handler = Groovepacker::Stores::Handlers::ShoplineHandler.new(store, import_item)
        when 'BigCommerce'
          handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(store, import_item)
        when 'Teapplix'
          handler = Groovepacker::Stores::Handlers::TeapplixHandler.new(store, import_item)
        when 'Veeqo'
          handler = Groovepacker::Stores::Handlers::VeeqoHandler.new(store, import_item)
        end
        handler
      end

      def common_data_attributes
        %w[fix_width fixed_width sep delimiter rows map map import_action
           contains_unique_order_items generate_barcode_from_sku use_sku_as_product_name
           order_placed_at order_date_time_format day_month_sequence encoding_format]
      end

      def build_data(map, store)
        map = fix_corrupted_map(map)
        data = { flag: 'ftp_download', type: 'order', store_id: store.id }
        common_data_attributes.each { |attr| data[attr.to_sym] = map[:map][attr.to_sym] }
        data
      end

      def fix_corrupted_map(map)
        return map unless map.map.class == String

        map.update(map: YAML.safe_load(map.map.gsub("!ruby/object:ActionController::Parameters\n  parameters: ", '').gsub("  permitted: false\n", '')))
        map.reload
      rescue StandardError
        map
      end

      def get_order_import_summary
        OrderImportSummary.where(status: 'import_initiate').where('updated_at <= ?', 2.minutes.ago).update_all(status: 'cancelled')

        return nil unless OrderImportSummary.where(status: 'import_initiate').empty?
        return nil if order_import_summaries.empty?

        @order_import_summary = order_import_summaries.first
        @order_import_summary.update(status: 'import_initiate')
        sleep(3)
        @order_import_summary.reload
      end

      def order_import_summaries
        @order_import_summaries ||= OrderImportSummary.where(status: 'not_started').order('updated_at DESC')
      end

      def delete_existing_order_import_summaries
        OrderImportSummary.where('status in (?)', %w[completed cancelled]).delete_all
      end

      def new_import_item(store_id, message = nil, status = nil)
        import_item = ImportItem.new
        import_item.store_id = store_id
        import_item.order_import_summary_id = @order_import_summary.id
        import_item.status = status
        import_item.message = message
        import_item.save!
      end

      def order_import_job(tenant, order_import_summary_id)
        Apartment::Tenant.switch!(tenant)
        ois = OrderImportSummary.find_by_id(order_import_summary_id)
        if ois
          track_changes(title: 'Import Started : Order Import Summary ' + ois.id.to_s, tenant: tenant,
                        username: (begin
                         User.find(ois.user_id).username
                                   rescue StandardError
                                     nil
                       end) || 'GP App', object_id: ois.id)
          ois.update(status: 'in_progress')
          ois.import_items.each { |import_item| ImportOrders.new.import_orders_with_import_item(import_item, tenant) }
          ois.reload
          ois.update(status: 'completed') unless ois.status == 'cancelled'
        end
        GC.start
      end
    end
  end
end
