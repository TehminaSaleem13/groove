# frozen_string_literal: true

class Expo::NewScanVerifyingService < ScanPack::Base
  def initialize(args)
    @current_user, @input, @id = args
    @result = {
      'status' => true,
      'matched' => false,
      'error_messages' => [],
      'success_messages' => [],
      'notice_messages' => [],
      'data' => {
        'next_state' => 'scanpack.rfp.verifying'
      }
    }
    @order = Order.where(id: @id).last
    @scanpack_settings_post_scanning_option_second = ScanPackSetting.last.post_scanning_option_second
  end

  def run
    scan_verifying
    @result
  end

  def scan_verifying
    tracking_num = @order.tracking_num.try(:gsub, /^(\#*)/, '').try { |a| a.gsub(/(\W)/) { |c| "\\#{c}" } }
    case true
    when @input.present? && tracking_num && @input.match(/#{tracking_num}/).present?
      @order.update_columns(post_scanning_flag: 'Verify')
      do_if_tracking_number_eql_input
    when @input.present? && (@input == @current_user.confirmation_code)
      @order.update_columns(post_scanning_flag: 'Verify')
      do_if_input_eql_confirmation_code
    end
  end

  def do_if_tracking_number_eql_input
    @order.addactivity("Shipping Label Verified: #{@order.tracking_num}", @current_user.username)
    @order.save
    if @scanpack_settings_post_scanning_option_second == 'None' || @scanpack_settings_post_scanning_option_second == 'Verify'
      @order.set_order_to_scanned_state(@current_user.username)
      @result['data'].merge!(
        'order_complete' => true,
        'next_state' => 'scanpack.rfo'
      )
    else
      apply_second_action
    end
  end

  def do_if_input_eql_confirmation_code
    if @scanpack_settings_post_scanning_option_second == 'None' || @scanpack_settings_post_scanning_option_second == 'Verify'
      @result['matched'] = false
      @order.set_order_to_scanned_state(@current_user.username)
      @result['data'].merge!(
        'order_complete' => true,
        'next_state' => 'scanpack.rfo'
      )
      @order.save
    else
      apply_second_action
    end
  end

  def apply_second_action
    case @scanpack_settings_post_scanning_option_second
    when 'Record'
      @result['data']['next_state'] = 'scanpack.rfp.recording'
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
