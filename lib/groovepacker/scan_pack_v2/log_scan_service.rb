# frozen_string_literal: true

module Groovepacker
  module ScanPackV2
    class LogScanService
      include ScanPackHelper

      def process_logs(tenant, current_user_id, session = {}, params)
        Apartment::Tenant.switch! tenant
        @params = params
        session = session.present? ? session : {}
        current_user = User.find_by_id current_user_id
        @params[:data] = JSON.parse(Net::HTTP.get(URI.parse(params[:data]))).map(&:with_indifferent_access) if params[:delayed_log_process]
        (@params[:data] || []).each do |scn_params|
          # sleep 0.5

          if scn_params[:event] == 'regular'
            scan_barcode_obj = ScanPack::ScanBarcodeService.new(
              current_user, session, scn_params
            )
            res = scan_barcode_obj.run
          elsif scn_params[:event] == 'click_scan'
            scn_params = attach_temporary_barcode(scn_params)
            res = product_scan_v2(
              scn_params[:input], 'scanpack.rfp.default', scn_params[:id], scn_params[:box_id],scn_params[:on_ex],
              clicked: true, current_user: current_user, session: session
            )
            remove_temporary_barcode(params)
          elsif scn_params[:event] == 'type_scan'
            res = product_scan_v2(
              scn_params[:input], 'scanpack.rfp.default', scn_params[:id], scn_params[:box_id],  @scn_params[:on_ex],
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
                [current_user, scn_params[:input], 'scanpack.rfp.no_tracking_info', scn_params[:id]]
              )
              render_order_scan_object.run
            elsif scn_params[:state] == 'scanpack.rfp.no_match'
              render_order_scan_object = ScanPack::ScanAginOrRenderOrderScanService.new(
                [current_user, scn_params[:input], 'scanpack.rfp.no_match', scn_params[:id]]
              )
              render_order_scan_object.run
            else
              scan_verifying_object = ScanPack::ScanVerifyingService.new(
                [current_user, scn_params[:input], scn_params[:id]]
              )
            end
            scan_verifying_object.run
          elsif scn_params[:event] == 'record'
            scan_recording_object = ScanPack::ScanRecordingService.new(
              [current_user, scn_params[:input], scn_params[:id]]
            )
            scan_recording_object.run
          elsif scn_params[:event] == 'serial_scan'
            serial_scan_obj = ScanPack::SerialScanService.new(
              current_user, session, scn_params
            )
            serial_scan_obj.run
          elsif scn_params[:event] == 'bulk_scan'
            order_item = OrderItem.find_by(id: scn_params[:order_item_id])
            if order_item && order_item.scanned_status != 'scanned'
              order = order_item.order
              order_item.update_attributes(scanned_status: 'scanned')
              order.addactivity("#{order_item.product.name} scanned through Bulk Scan", current_user.try(:username))
              order.set_order_to_scanned_state(current_user.try(:username)) unless order.has_unscanned_items
            end
          end
        rescue StandardError => e
          on_demand_logger = Logger.new("#{Rails.root}/log/scan_pack_v2.log")
          log = { tenant: Apartment::Tenant.current, params: @params, scn_params: scn_params, error: e, time: Time.current.utc, backtrace: e.backtrace.join(',') }
          on_demand_logger.info(log)
        end
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
