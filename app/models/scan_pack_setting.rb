class ScanPackSetting < ActiveRecord::Base
  attr_accessible :ask_tracking_number, :enable_click_sku,
                  :enable_click_sku, :ask_tracking_number, :show_success_image,
                  :show_order_complete_image, :success_image_time,
                  :order_complete_image_time, :play_success_sound,
                  :play_order_complete_sound, :show_fail_image, :fail_image_time,
                  :play_fail_sound, :skip_code_enabled, :skip_code,
                  :note_from_packer_code_enabled, :note_from_packer_code,
                  :service_issue_code_enabled, :service_issue_code,
                  :restart_code_enabled, :restart_code,
                  :type_scan_code_enabled, :type_scan_code, :post_scanning_option,
                  :escape_string_enabled, :escape_string, :record_lot_number,
                  :show_customer_notes, :show_internal_notes,
                  :scan_by_tracking_number, :intangible_setting_enabled,
                  :intangible_string, :intangible_setting_gen_barcode_from_sku,
                  :post_scan_pause_enabled, :post_scan_pause_time, :display_location,
                  :string_removal_enabled, :string_removal, :first_escape_string_enabled, 
                  :second_escape_string_enabled, :second_escape_string, :order_verification, :scan_by_hex_number, :return_to_orders, :scanning_sequence, :click_scan, :click_scan_barcode, :scanned, :scanned_barcode, :post_scanning_option_second, :require_serial_lot, :valid_prefixes, :replace_gp_code,
                  :single_item_order_complete_msg, :single_item_order_complete_msg_time, :multi_item_order_complete_msg, :multi_item_order_complete_msg_time, :tote_identifier, :show_expanded_shipments, :tracking_number_validation_enabled, :tracking_number_validation_prefixes

  def self.is_action_code(code)
    setting = all.first
    string_code = code.to_s
    (
    (string_code == setting.skip_code.to_s) ||
      (string_code == setting.note_from_packer_code) ||
      (string_code == setting.service_issue_code) ||
      (string_code == setting.restart_code)
    )
  end
end
