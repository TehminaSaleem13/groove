# frozen_string_literal: true

class ScanPack::ScanRecordingService < ScanPack::Base
  def initialize(args)
    @current_user, @input, @id, @on_ex = args
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
    case true
    when @input.blank?
      set_error_messages('No tracking number is provided')
    when @order.blank?
      set_error_messages('Could not find order with id: ' + @id.to_s)
    else
      scan_recording
    end
    @result
  end

  def scan_recording
    @result['data']['next_state'] = 'scanpack.rfp.recording'
    if @order.status.in?(['awaiting', 'scanned'])
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
      set_error_messages('The order is not in awaiting or scanned state. Cannot scan the tracking number')
    end
  end

  def check_tracking_number_validation
    set_tracking_info && return unless @scanpack_setting.tracking_number_validation_enabled
    @input.starts_with?(*@scanpack_setting.tracking_number_validation_prefixes.to_s.split(',').map(&:strip)) ? set_tracking_info : set_error_messages('Doh! The tracking number you have scanned does not appear to be valid. If this scan should be permitted please check your Tracking Number Validation setting in Settings > System > Scan & Pack > Post Scanning Functions')
  end

  def set_tracking_info
    @order.tracking_num = @input
    @order.set_order_to_scanned_state(@current_user.username, @on_ex)
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
        @order.addactivity('Tracking information was not imported with this order so the shipping label could not be verified ', @current_user.username, @on_ex)
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
    @order.set_order_to_scanned_state(@current_user.username, @on_ex)
    @result['data']['order_complete'] = true
    @result['data']['next_state'] = 'scanpack.rfo'
  end
end
