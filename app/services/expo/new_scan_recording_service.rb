# frozen_string_literal: true

class Expo::NewScanRecordingService < ScanPack::Base
  def initialize(args)
    @current_user, @input, @id = args
    @result = {
      'status' => true,
      'matched' => false,
      'error_messages' => [],
      'success_messages' => [],
      'notice_messages' => [],
      'data' => {}
    }
    @order = Order.where(id: @id).last
    @scanpack_settings_post_scanning_option_second = ScanPackSetting.last.post_scanning_option_second
    @scanpack_setting = ScanPackSetting.last
  end

  def run
    scan_recording
    @result
  end

  def scan_recording
    @result['data']['next_state'] = 'scanpack.rfp.recording'
    if @order.status == 'awaiting'
      # allow tracking id to be saved without special permissions
      if @scanpack_settings_post_scanning_option_second == 'None' || @scanpack_settings_post_scanning_option_second == 'Record'
        check_tracking_number_validation
      else
        @order.tracking_num = @input
        @order.post_scanning_flag = 'Record'
        @order.save
        apply_second_action
      end
    else
      set_error_messages('The order is not in awaiting state. Cannot scan the tracking number')
    end
  end

  def check_tracking_number_validation
    set_tracking_info && return unless @scanpack_setting.tracking_number_validation_enabled
    set_tracking_info
  end

  def set_tracking_info
    @order.tracking_num = @input
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data']['order_complete'] = true
    @result['data']['next_state'] = 'scanpack.rfo'
    # update inventory when inventory warehouses is implemented.
    @order.save
  end

  def apply_second_action
    case @scanpack_settings_post_scanning_option_second
    when 'Verify'
      if @order.tracking_num.present?
        @result['data']['next_state'] = 'scanpack.rfp.verifying'
      else
        @result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
        @order.addactivity('Tracking information was not imported with this order so the shipping label could not be verified ', @current_user.username)
        end
    when 'PackingSlip'
      do_set_order_scanned_state_and_result_data
      generate_packing_slip(@order)
    when 'Barcode'
      do_set_order_scanned_state_and_result_data
      generate_order_barcode_slip(@order)
    else
      do_set_order_scanned_state_and_result_data
      end
  end

  def do_set_order_scanned_state_and_result_data
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data']['order_complete'] = true
    @result['data']['next_state'] = 'scanpack.rfo'
  end
end
