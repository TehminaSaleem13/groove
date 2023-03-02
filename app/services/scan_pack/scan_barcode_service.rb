# frozen_string_literal: true

module ScanPack
  class ScanBarcodeService < ScanPack::Base
    include ScanPackHelper

    def initialize(current_user, session, params)
      set_scan_pack_action_instances(current_user, session, params)
      @order = Order.where(id: @params[:id]).first
    end

    def run
      if @params[:state].present?
        scan_barcode
      else
        @result['status'] &= false
        @result['error_messages'].push('Please specify a state')
      end
      @result
    end

    def scan_barcode
      do_set_state_matcher
      do_check_state_and_status_to_add_activity
      do_scan_now
      if @result['data'].present? && @result['data']['order'].present? && !@params[:app]
        order = Order.find_by_increment_id(@result['data']['order']['increment_id'])
        @result['data']['order']['store_type'] = begin
                                                   order.store.store_type
                                                 rescue StandardError
                                                   nil
                                                 end
        @result['data']['order']['popup_shipping_label'] = order.store.shipping_easy_credential.popup_shipping_label if @result['data']['order']['store_type'] == 'ShippingEasy' && order.store.shipping_easy_credential.present?
        @result['data']['order']['large_popup'] = order.store.shipping_easy_credential.large_popup if @result['data']['order']['store_type'] == 'ShippingEasy' && order.store.shipping_easy_credential.present?
        @result['data']['order']['order_cup_direct_shipping'] = order.order_cup_direct_shipping
        @result['data']['order']['multiple_lines_per_sku_accepted'] = order.store.shipping_easy_credential.multiple_lines_per_sku_accepted if @result['data']['order']['store_type'] == 'ShippingEasy' && order.store.shipping_easy_credential.present?
        @result['data']['order']['store_order_idea'] = begin
                                                         order.store_order_id
                                                       rescue StandardError
                                                         nil
                                                       end
        @result['data']['order']['use_api_create_label'] = order.store.shipstation_rest_credential.use_api_create_label if @result['data']['order']['store_type'] == 'Shipstation API 2'
        # @result['data']['order']['ss_label_data'] = order.store.shipstation_rest_credential.fetch_label_related_data(order.ss_label_data, order.increment_id, order.store_order_id) if !order.has_unscanned_items && @result['data']['order']['use_api_create_label']
        @result['data']['order']['use_chrome_extention'] = order.store.shipstation_rest_credential.use_chrome_extention if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        @result['data']['order']['switch_back_button'] = order.store.shipstation_rest_credential.switch_back_button if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        @result['data']['order']['auto_click_create_label'] = order.store.shipstation_rest_credential.auto_click_create_label if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        @result['data']['order']['return_to_order'] = order.store.shipstation_rest_credential.return_to_order if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        do_set_result_for_boxes(order)
        @result['data']['order'] = order.get_se_old_shipments(@result['data']['order'])
        # @result["data"]["order"]['se_duplicate_orders'] = se_duplicate_orders(order) if order.store.store_type == 'ShippingEasy'
        # @result["data"]["order"]['se_old_shipments'] = se_old_shipments(order) if order.store.store_type == 'ShippingEasy' if @result["data"]['order']['se_duplicate_orders'].blank?
        # @result["data"]["order"]['se_all_shipments'] = se_all_shipments(order) if order.store.store_type == 'ShippingEasy' && @result["data"]["order"]['se_old_shipments'].blank?
      end
      if @result['data']['next_state'] == 'scanpack.rfo' && !@result['matched'] && @result['do_on_demand_import']
        #  stores = Store.where("status=? and on_demand_import=?", true, true)
        stores = Store.where('status=? and on_demand_import=?', true, true) | Store.where('status=? and store_type=?', true, 'Shipstation API 2')
        check_stores = Store.where('status=? and on_demand_import_v2=?', true, true)
        run_import_for_not_found_order if stores.present? || check_stores.present?
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
        'scanpack.rfp.confirmation.product_edit' => %w[product_edit_conf order_scan],
        'scanpack.rfp.confirmation.order_edit' => %w[order_edit_conf order_scan],
        'scanpack.rfp.confirmation.cos' => %w[cos_conf order_scan]
      }
    end

    def do_scan_now
      rem_qty = begin
                  @params['rem_qty'] || @params['scan_pack']['rem_qty']
                rescue StandardError
                  nil
                end
      barcode = ProductBarcode.where(barcode: @params[:input]).last
      packing_count = begin
                        barcode.packing_count
                      rescue StandardError
                        1
                      end
      if packing_count.present? && packing_count.to_i > 1 && barcode.product_id.present?
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

      if @params[:state] == 'scanpack.rfp.default' && @result['status'] == true
        item_sku = Product.includes(:order_items, :product_barcodes, :product_skus).where.not(order_items: { scanned_status: 'scanned' }).where(product_barcodes: { barcode: @params[:input] }, order_items: { order_id: @order.id }).first&.primary_sku
        add_activity_for_barcode(item_sku)
      end
    end


    def update_activity(output)
      return unless @params[:state] == 'scanpack.rfp.default' && output['status'] == false && @order

      latest_activity = @order.order_activities.last
      latest_activity.update_attribute(:action, "INVALID SCAN - #{latest_activity.action}")
    end

    def run_import_for_not_found_order
      stores = Store.where('status=? and store_type NOT IN (?)', true, %w[CSV system])
      if stores.present?
        order_no_input = @params['input']
        job = Delayed::Job.find_by_queue("on_demand_scan_#{Apartment::Tenant.current}_#{order_no_input}")
        if job.blank? || job.failed_at.present?
          store = stores.where(status: true, store_type: ['Shipstation API 2', 'Shopify', 'ShippingEasy']).last
          add_on_demand_import_to_delay(order_no_input, job, store)
        else
          @result['notice_messages'] = 'Still checking on this order.'
        end
      end
    end

    def do_set_result_for_boxes(order)
      result = order.get_boxes_data
      @result['data']['order']['box'] = result[:box]
      @result['data']['order']['order_item_boxes'] = result[:order_item_boxes]
    end

    def do_if_packing_count_present(rem_qty, barcode, packing_count)
      if rem_qty.present? && rem_qty >= packing_count.to_i
        product_scan_object = ScanPack::ProductScanService.new(
          [
            @current_user, @session,
            @params[:input], @params[:state], @params[:id], @params[:box_id], @params[:on_ex], barcode.packing_count.to_i || 1
          ]
        )
        @result = product_scan_object.run(false, false, true)
      else
        @result['error_messages'].push("The pack barcode scanned exceeds the number of units of SKU #{@params[:input]} in this order")
      end
    end

    def do_if_packing_count_not_present
      @matcher[@params[:state]].each do |state_func|
        output = if state_func == 'product_scan' && @params[:app]
                   send(
                     'product_scan_v2', @params[:input], @params[:state], @params[:id], @params[:box_id], @params[:on_ex],
                     current_user: @current_user, session: @session
                   )
                 elsif state_func == 'product_scan'
                   send(
                     state_func, @params[:input], @params[:state], @params[:id], @params[:box_id], @params[:on_ex],
                     current_user: @current_user, session: @session
                   )
                 elsif state_func == 'order_scan' && @params[:app]
                   send(
                     'order_scan_v2', @params[:input], @params[:state], @params[:id], @params[:store_order_id],
                     {
                       current_user: @current_user, session: @session
                     },
                     @params
                   )
                 elsif state_func == 'order_scan'
                   send(
                     state_func, @params[:input], @params[:state], @params[:id], @params[:store_order_id],
                     current_user: @current_user, session: @session, order_by_number: @params[:order_by_number].to_b
                   )
                 else
                   send(
                     state_func, @params[:input], @params[:state], @params[:id],
                     current_user: @current_user, session: @session
                   )
                 end
        do_set_result(output)
        update_activity(output)
        break if output['matched']
      end
    end
  end
end
