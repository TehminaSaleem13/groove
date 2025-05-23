# frozen_string_literal: true

module Groovepacker
  module ScanPackV2
    class LogScanService
      include ScanPackHelper

      def process_logs(tenant_name, current_user_id, session = {}, params)
        Apartment::Tenant.switch! tenant_name
        @params = params
        session = session.present? ? session : {}
        current_user = User.find_by_id current_user_id
        tenant = Tenant.find_by_name(tenant_name)
        @params[:data] = JSON.parse(Net::HTTP.get(URI.parse(params[:data]))).map(&:with_indifferent_access) if params[:delayed_log_process]
        (@params[:data] || []).each do |scn_params|
          if scn_params[:event] == 'regular'
            scan_barcode_obj = ScanPack::ScanBarcodeService.new(
              current_user, session, scn_params
            )
            @result = scan_barcode_obj.run
          elsif scn_params[:event] == 'click_scan'
            scn_params = attach_temporary_barcode(scn_params)
            @result = product_scan_v2(
              scn_params[:input], 'scanpack.rfp.default', scn_params[:id], scn_params[:box_id], scn_params[:on_ex],
              scn_params[:order_item_id],clicked: true, current_user: current_user, session: session
            )
            remove_temporary_barcode(params)
          elsif scn_params[:event] == 'type_scan'
            res = product_scan_v2(
              scn_params[:input], 'scanpack.rfp.default', scn_params[:id], scn_params[:box_id], scn_params[:on_ex], scn_params[:order_item_id],
              clicked: false, serial_added: false, typein_count: scn_params[:count].to_i,
              current_user: current_user, session: session, type_scan: true
            )
          elsif scn_params[:event] == 'scanned'
            order = Order.find(scn_params[:id])
            unless order.nil?
              order.order_items.update_all(scanned_status: 'scanned')
              order.addactivity('Order is scanned through SCANNED barcode', current_user.try(:username))
              order.set_order_to_scanned_state(current_user.try(:username), scn_params[:on_ex])
            end
          elsif scn_params[:event] == 'note'
            ScanPack::AddNoteService.new(
              current_user, session, id: scn_params[:id], note: scn_params[:message], email: true
            ).run
          elsif scn_params[:event] == 'verify'
            if scn_params[:state] == 'scanpack.rfp.no_tracking_info'
              render_order_scan_object = ScanPack::RenderOrderScanService.new(
                [current_user, scn_params[:input], 'scanpack.rfp.no_tracking_info', scn_params[:id], scn_params[:on_ex]]
              )
              render_order_scan_object.run
            elsif scn_params[:state] == 'scanpack.rfp.no_match'
              render_order_scan_object = ScanPack::ScanAginOrRenderOrderScanService.new(
                [current_user, scn_params[:input], 'scanpack.rfp.no_match', scn_params[:id], scn_params[:on_ex]]
              )
              render_order_scan_object.run
            else
              scan_verifying_object = ScanPack::ScanVerifyingService.new(
                [current_user, scn_params[:input], scn_params[:id], scn_params[:on_ex]]
              )
            end
            scan_verifying_object.run
          elsif scn_params[:event] == 'record'
            scan_recording_object = ScanPack::ScanRecordingService.new(
              [current_user, scn_params[:input], scn_params[:id], scn_params[:on_ex]]
            )
            scan_recording_object.run
          elsif scn_params[:event] == 'serial_scan'
            serial_scan_obj = ScanPack::SerialScanService.new(
              current_user, session, scn_params
            )
            @result = serial_scan_obj.run
          elsif scn_params[:event] == 'bulk_scan' || scn_params[:event] == 'scan_all_items'
            order_item = OrderItem.find_by(id: scn_params[:order_item_id])
            order = order_item.order
            return unless order_item

            if order_item.product.is_kit == 0
              if order_item && order_item.scanned_status != 'scanned'
                order_item.update(scanned_status: 'scanned')
                order_item.update(scanned_qty: order_item.qty)
                add_all_scan_logs(order, order_item, scn_params, current_user, nil)
                order.set_order_to_scanned_state(current_user.try(:username), scn_params[:on_ex]) unless order.has_unscanned_items
              end
            else
              product_kit_sku = order_item.product.product_kit_skuss.find_by_option_product_id(scn_params[:product_id])
              order_item_kit_product = order_item.order_item_kit_products.find_by(product_kit_skus: product_kit_sku)
              if order_item_kit_product && order_item_kit_product.scanned_status != 'scanned'
                order_item_kit_product.update(scanned_status: 'scanned')
                if order_item.order_item_kit_products.where.not(scanned_status: 'scanned').any?
                  order_item.update(scanned_status: 'partially_scanned')
                else
                  order_item.update(scanned_status: 'scanned')
                  order_item.update(scanned_qty: order_item.qty)
                end
                order_item_kit_product.update(scanned_qty: product_kit_sku.qty)
                add_all_scan_logs(order, order_item, scn_params, current_user, 'kit')
                order.set_order_to_scanned_state(current_user.try(:username), scn_params[:on_ex]) unless order.has_unscanned_items
              end
            end
          end
        rescue StandardError => e
          log = { tenant: tenant_name, params: @params, scn_params: scn_params, error: e, time: Time.current.utc, backtrace: e.backtrace.first(5).join(',') }
          Groovepacker::LogglyLogger.log(tenant_name, 'GPX-order-scan-api-failure', log)
          scan_pack_logger = Logger.new("#{Rails.root}/log/scan_pack_v2.log")
          scan_pack_logger.info(log)
        end
        @result
      end

      def add_all_scan_logs(order, order_item, scn_params, current_user, type = nil)
        scan_type = scn_params[:event] == 'bulk_scan' ? 'Bulk Scan' : 'Scan-All Option'
        scan_description = "#{order_item.product.name} scanned through #{scan_type}"
        scan_description += " from #{type}" if type == 'kit'

        username = current_user.try(:username)

        order.addactivity(scan_description, username, scn_params[:on_ex])
      end

      private

      def attach_temporary_barcode(params)
        if params[:event] == 'click_scan' && params[:input].blank?
          order_item = OrderItem.find_by_id(params[:order_item_id])
          product = if params[:is_kit] == true
                      Product.find_by_id(params[:product_id])
                    else
                      order_item&.product
                    end
          return params unless product

          return params if product.product_barcodes.any?

          temp_barcode = "#{product.id}_#{Time.current.to_i}"
          params[:barcode_id] = product.product_barcodes.create(barcode: temp_barcode)&.id
          order_item&.product&.delete_cache
          params[:input] = temp_barcode
        end
        params
      end

      def remove_temporary_barcode(params)
        order_item = OrderItem.find_by_id(params[:order_item_id])
        ProductBarcode.find_by_id(params['data'][0]['barcode_id'])&.destroy
        order_item&.product&.delete_cache
      end
    end
  end
end
