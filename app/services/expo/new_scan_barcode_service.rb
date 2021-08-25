module Expo
    class NewScanBarcodeService < ScanPack::Base
      include ScanPackHelper
  
      def initialize(current_user, session, params)
        set_scan_pack_action_instances(current_user, session, params)
        @order = Order.where(id: @params[:id]).first
      end
  
      def run
        scan_barcode
        @result
      end
  
      def scan_barcode
        do_set_state_matcher
        do_check_state_and_status_to_add_activity
        do_scan_now

        if @result["data"]["next_state"]=="scanpack.rfo" && !@result["matched"] && @result['do_on_demand_import']
        #  stores = Store.where("status=? and on_demand_import=?", true, true)
         stores = Store.where("status=? and on_demand_import=?", true, true) | Store.where("status=? and store_type=?", true, 'Shipstation API 2')
         check_stores = Store.where("status=? and on_demand_import_v2=?", true, true)
         run_import_for_not_found_order if (stores.present? || check_stores.present?)
        end
      end
  
      def do_set_state_matcher
        @matcher = {
          'scanpack.rfo' => ['order_scan'],
          'scanpack.rfp.default' => ['product_scan'],
          'scanpack.rfp.recording' => ['scan_recording'],
          'scanpack.rfp.verifying' => ['scan_verifying'],
          'scanpack.rfp.no_tracking_info' => ['render_order_scan'],
          'scanpack.rfp.no_match' => ['scan_again_or_render_order_scan'],
          'scanpack.rfp.product_edit' => ['order_scan'],
          'scanpack.rfp.product_edit.single' => ['order_scan'],
          'scanpack.rfp.confirmation.product_edit' => ['product_edit_conf', 'order_scan'],
          'scanpack.rfp.confirmation.order_edit' => ['order_edit_conf', 'order_scan'],
          'scanpack.rfp.confirmation.cos' => ['cos_conf', 'order_scan']
        }
      end
  
      def do_scan_now
        rem_qty = @params["rem_qty"] || @params["scan_pack"]["rem_qty"] rescue nil
        barcode = ProductBarcode.where(barcode: @params[:input]).last
        packing_count = barcode.packing_count rescue 1
        if packing_count.present? && packing_count.to_i > 1
          do_if_packing_count_present(rem_qty, barcode, packing_count)
        else
          do_if_packing_count_not_present
        end
      end
  
      def do_set_result(output)
        @result['error_messages'].push(*output['error_messages'])
        @result['success_messages'].push(*output['success_messages'])
        @result['notice_messages'].push(*output['notice_messages'])
        @result['status'] = output['status']
        @result['data'] = output['data']
        @result['matched'] = output['matched']
        @result['do_on_demand_import'] = output['do_on_demand_import']
      end
  
      def do_check_state_and_status_to_add_activity
        return unless @order
        if @params[:state] == "scanpack.rfp.default" && @result['status'] == true
          current_product_id = ProductBarcode.where(barcode: @params["input"])[0].try(:product_id)
          item_sku = ProductSku.where(product_id: current_product_id)[0].try(:sku)
          add_activity_for_barcode(item_sku)
        end
      end
  
      def add_activity_for_barcode(item_sku)
        if @params[:box_id].nil?
          GeneralSetting.last.multi_box_shipments? ? @order.addactivity("Product with barcode: #{@params[:input]} and sku: #{item_sku} scanned in Box 1", @current_user.name) :  @order.addactivity("Product with barcode: #{@params[:input]} and sku: #{item_sku} scanned", @current_user.name)
        else
          box = Box.where(id: @params[:box_id]).last
          @order.addactivity("Product with barcode: #{@params[:input]} and sku: #{item_sku} scanned in #{box.try(:name)}", @current_user.name)
        end  
      end
  
      def update_activity(output)
        return unless  @params[:state] == "scanpack.rfp.default" && output['status'] == false && @order
        latest_activity = @order.order_activities.last
        latest_activity.update_attribute(:action, "INVALID SCAN - #{latest_activity.action}")
      end
  
      def run_import_for_not_found_order
        stores = Store.where("status=? and store_type NOT IN (?)", true, ['CSV', 'system'])
        if stores.present?
          order_no_input = @params["input"]
          job = Delayed::Job.find_by_queue("on_demand_scan_#{Apartment::Tenant.current}_#{order_no_input}")
          if job.blank? || job.failed_at.present?
            store = stores.where(store_type: 'Shipstation API 2').last
            add_on_demand_import_to_delay(order_no_input, job, store)
          else
            @result["notice_messages"]="Still checking on this order."
          end
        end
      end
  
      def do_if_packing_count_present(rem_qty, barcode, packing_count)
        if rem_qty.present? && rem_qty >= packing_count.to_i
          product_scan_object = Expo::NewProductScanService.new(
            [
              @current_user, @session,
              @params[:input], @params[:state], @params[:id], @params[:box_id], barcode.packing_count.to_i || 1
            ]
          )
          @result = product_scan_object.run(false, false, true)
        else
          @result['error_messages'].push("The pack barcode scanned exceeds the number of units of SKU #{@params[:input]} in this order")
        end
      end
  
      def do_if_packing_count_not_present
        @matcher[@params[:state]].each do |state_func|
          if state_func == "product_scan" && @params[:app]
            output = send(
              'product_scan_v2', @params[:input], @params[:state], @params[:id], @params[:box_id],
              {
                current_user: @current_user, session: @session
              }
            )
          elsif state_func == "order_scan" && @params[:app]
            output = send(
              'order_scan_v2', @params[:input], @params[:state], @params[:id], @params[:store_order_id],
              {
                current_user: @current_user, session: @session
              },
              @params
            )
          else
            output = send(
              state_func, @params[:input], @params[:state], @params[:id],
              {
                current_user: @current_user, session: @session
              }
            )
          end
          do_set_result(output)
          update_activity(output)
          break if output["matched"]
        end
      end
    end
  end
