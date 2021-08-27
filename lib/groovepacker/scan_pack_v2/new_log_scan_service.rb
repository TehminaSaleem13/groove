module Groovepacker
    module ScanPackV2
      class NewLogScanService
        include ScanPackHelper
  
        def process_logs(tenant, current_user_id, session = {}, params)
          Apartment::Tenant.switch! tenant
          @params = params
          session = session.present? ? session : {}
          current_user = User.find_by_id current_user_id
          @params[:data] = JSON.parse(Net::HTTP.get(URI.parse(params[:data]))).map(&:with_indifferent_access)
          @params[:data].each do |scn_params|
            sleep 0.5
            begin
              if (scn_params[:event] == 'note')
                Expo::NewAddNoteService.new(
                  current_user, session, { id: scn_params[:id], note: scn_params[:message], email: true }
                ).run
              elsif (scn_params[:actionBarcode] == 'true')
                product_scan_object = Expo::NewProductScanService.new(
                  [
                    current_user, session,
                    scn_params[:input], scn_params[:state], scn_params[:id], scn_params[:box_id], 1
                  ]
                )
                @result = product_scan_object.run(false, false, true)  
              else
                order = Order.find(scn_params[:id])
                order_item = OrderItem.find_by(id: scn_params[:order_item_id])
                scanned_qty = order_item.qty - scn_params[:qty_rem].to_i
                if scn_params[:qty_rem].to_i != 0
                  order_item.update(scanned_qty: scanned_qty, scanned_status: "partially_scanned" )
                else
                  order.update(status: "scanned")
                  order.order_items.update_all(scanned_status: 'scanned', scanned_qty: scanned_qty )
                end
              end  
            #   elsif (scn_params[:event] == 'scanned')
            #     order = Order.find(scn_params[:id])
            #     if !order.nil?
            #       order.order_items.update_all(scanned_status: 'scanned')
            #       order.addactivity('Order is scanned through SCANNED barcode', current_user.try(:username))
            #       order.set_order_to_scanned_state(current_user.try(:username))
            #     end
            #   elsif (scn_params[:event] == 'bulk_scan')
            #     order_item = OrderItem.find_by(id: scn_params[:order_item_id])
            #     # if order_item && order_item.scanned_status != 'scanned'
            #       order = order_item.order
            #       order_item.update_attributes(scanned_status: 'scanned')
            #       order.addactivity("#{order_item.product.name} scanned through Bulk Scan", current_user.try(:username))
            #       order.set_order_to_scanned_state(current_user.try(:username)) unless order.has_unscanned_items
            #     # end
            #   end
            rescue => e
              on_demand_logger = Logger.new("#{Rails.root}/log/scan_pack_v2.log")
              log = { tenant: Apartment::Tenant.current, params: @params, scn_params: scn_params, error: e, time: Time.now.utc, backtrace: e.backtrace.join(",") }
              on_demand_logger.info(log)
            end
          end
        end
      end
    end
  end
