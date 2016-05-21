module ScanPack
  class ScanBarcodeService < ScanPack::Base
    include ScanPackHelper
    
    def initialize(current_user, session, params)
      set_scan_pack_action_instances(current_user, session, params)
    end

    def run
      unless @params[:state].present?
        @result['status'] &= false
        @result['error_messages'].push("Please specify a state")
      else
        scan_barcode
      end
      @result
    end

    def scan_barcode
      do_set_state_matcher
      do_check_state_and_status_to_add_activity
      do_scan_now
      if @result["data"]["next_state"]=="scanpack.rfo" and @result["matched"]==false
       stores = Store.where("status=? and on_demand_import=?", true, true)
       run_import_for_not_found_order if stores.present?
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
      @matcher[@params[:state]].each do |state_func|
        output = send(
          state_func, @params[:input], @params[:state], @params[:id],
          {
            current_user: @current_user, session: @session
          }
        )
        do_set_result(output)
        break if output["matched"]
      end
    end

    def do_set_result(output)
      @result['error_messages'].push *output['error_messages']
      @result['success_messages'].push *output['success_messages']
      @result['notice_messages'].push *output['notice_messages']
      @result['status'] = output['status']
      @result['data'] = output['data']
      @result['matched'] = output['matched']
    end

    def do_check_state_and_status_to_add_activity
      if @params[:state] == "scanpack.rfp.default" && @result['status'] == true
        Order.find(@params[:id]).addactivity("Product with barcode: #{@params[:input]} scanned", @current_user.name)
      end
    end

    def run_import_for_not_found_order
      stores = Store.where("status=? and store_type NOT IN (?)", true, ['CSV', 'system'])
      if stores.present?
        current_tenant = Apartment::Tenant.current
        order_no_input = @params["input"]
        order_importer = Groovepacker::Stores::Importers::OrdersImporter.new(nil)
        order_importer.delay(:run_at => 1.seconds.from_now).search_and_import_single_order(tenant: current_tenant, order_no: order_no_input)
        @result["notice_messages"]="It does not look like that order has been imported into GroovePacker. We'll attempt to import it in the background and you can continue scanning other orders while it imports."
      end
    end
  end
end