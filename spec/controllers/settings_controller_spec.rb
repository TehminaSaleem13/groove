# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SettingsController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    access_restriction = FactoryBot.create(:access_restriction)
    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    @store = FactoryBot.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true)
    @order = FactoryBot.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: @store,
                                       prime_order_id: '1660160213', store_order_id: '1660160213')
    csv_mapping = FactoryBot.create(:csv_mapping, store_id: @store.id)
  end

  after do
    @tenant.destroy
  end

  describe 'Get Scan Pack Settings' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      allow(token1).to receive(:id).and_return(nil)
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Destroy all existing tokes if logged in from EX App' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      @user.role.update(edit_general_prefs: true)

      request.headers[:EXAPP] = true
      request.accept = 'application/json'
      printing_setting = PrintingSetting.create
      post :get_settings, params: { app: true }
      expect(response.status).to eq(200)
    end
  end

  describe 'Update Scan Pack Settings' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Tags Switch' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      @user.role.update(edit_scanning_prefs: true)

      request.accept = 'application/json'
      post :update_scan_pack_settings,
           params: { 'id' => 1, 'enable_click_sku' => true, 'requires_assigned_orders' => true, 'ask_tracking_number' => false,
                     'created_at' => '2021-07-28T12:57:11.000Z', 'updated_at' => '2021-08-05T08:53:56.000Z', 'show_success_image' => true, 'success_image_src' => '/assets/images/scan_success.png', 'success_image_time' => 0.5, 'show_fail_image' => true, 'fail_image_src' => '/assets/images/scan_fail.png', 'fail_image_time' => 1, 'play_success_sound' => true, 'success_sound_url' => '/assets/sounds/scan_success.mp3', 'success_sound_vol' => 0.75, 'play_fail_sound' => true, 'fail_sound_url' => '/assets/sounds/scan_fail.mp3', 'fail_sound_vol' => 0.75, 'skip_code_enabled' => true, 'skip_code' => 'SKIP', 'note_from_packer_code_enabled' => true, 'note_from_packer_code' => 'NOTE', 'service_issue_code_enabled' => true, 'service_issue_code' => 'ISSUE', 'restart_code_enabled' => true, 'restart_code' => 'RESTART', 'show_order_complete_image' => true, 'order_complete_image_src' => '/assets/images/scan_order_complete.png', 'order_complete_image_time' => 1, 'play_order_complete_sound' => true, 'order_complete_sound_url' => '/assets/sounds/scan_order_complete.mp3', 'order_complete_sound_vol' => 0.75, 'type_scan_code_enabled' => true, 'type_scan_code' => '*', 'post_scanning_option' => 'None', 'escape_string' => ' - ', 'escape_string_enabled' => false, 'record_lot_number' => false, 'show_customer_notes' => true, 'show_internal_notes' => true, 'scan_by_shipping_label' => false, 'intangible_setting_enabled' => true, 'intangible_string' => 'Coupon:', 'post_scan_pause_enabled' => false, 'post_scan_pause_time' => 4, 'intangible_setting_gen_barcode_from_sku' => true, 'display_location' => false, 'string_removal_enabled' => false, 'string_removal' => nil, 'first_escape_string_enabled' => false, 'second_escape_string_enabled' => false, 'second_escape_string' => nil, 'order_verification' => false, 'scan_by_packing_slip' => true, 'return_to_orders' => false, 'click_scan' => false, 'scanning_sequence' => 'any_sequence', 'click_scan_barcode' => 'CLICKSCAN', 'scanned' => false, 'scanned_barcode' => 'SCANNED', 'post_scanning_option_second' => 'None', 'require_serial_lot' => false, 'valid_prefixes' => nil, 'replace_gp_code' => true, 'single_item_order_complete_msg' => 'Labels Printing!', 'single_item_order_complete_msg_time' => 4, 'multi_item_order_complete_msg' => 'Collect all items from the tote!', 'multi_item_order_complete_msg_time' => 4, 'tote_identifier' => 'Tote', 'show_expanded_shipments' => true, 'tracking_number_validation_enabled' => false, 'tracking_number_validation_prefixes' => nil, 'partial' => false, 'partial_barcode' => 'PARTIAL', 'scan_by_packing_slip_or_shipping_label' => false, 'remove_enabled' => false, 'remove_barcode' => 'REMOVE', 'remove_skipped' => true, 'display_location2' => false, 'display_location3' => false, 'show_tags' => true, 'scan_pack_workflow' => 'default', 'tote_sets' => [], 'setting' => { 'id' => 1, 'enable_click_sku' => true, 'ask_tracking_number' => false, 'created_at' => '2021-07-28T12:57:11.000Z', 'updated_at' => '2021-08-05T08:53:56.000Z', 'show_success_image' => true, 'success_image_src' => '/assets/images/scan_success.png', 'success_image_time' => 0.5, 'show_fail_image' => true, 'fail_image_src' => '/assets/images/scan_fail.png', 'fail_image_time' => 1, 'play_success_sound' => true, 'success_sound_url' => '/assets/sounds/scan_success.mp3', 'success_sound_vol' => 0.75, 'play_fail_sound' => true, 'fail_sound_url' => '/assets/sounds/scan_fail.mp3', 'fail_sound_vol' => 0.75, 'skip_code_enabled' => true, 'skip_code' => 'SKIP', 'note_from_packer_code_enabled' => true, 'note_from_packer_code' => 'NOTE', 'service_issue_code_enabled' => true, 'service_issue_code' => 'ISSUE', 'restart_code_enabled' => true, 'restart_code' => 'RESTART', 'show_order_complete_image' => true, 'order_complete_image_src' => '/assets/images/scan_order_complete.png', 'order_complete_image_time' => 1, 'play_order_complete_sound' => true, 'order_complete_sound_url' => '/assets/sounds/scan_order_complete.mp3', 'order_complete_sound_vol' => 0.75, 'type_scan_code_enabled' => true, 'type_scan_code' => '*', 'post_scanning_option' => 'None', 'escape_string' => ' - ', 'escape_string_enabled' => false, 'record_lot_number' => false, 'show_customer_notes' => true, 'show_internal_notes' => true, 'scan_by_shipping_label' => false, 'intangible_setting_enabled' => true, 'intangible_string' => 'Coupon:', 'post_scan_pause_enabled' => false, 'post_scan_pause_time' => 4, 'intangible_setting_gen_barcode_from_sku' => true, 'display_location' => false, 'string_removal_enabled' => false, 'string_removal' => nil, 'first_escape_string_enabled' => false, 'second_escape_string_enabled' => false, 'second_escape_string' => nil, 'order_verification' => false, 'scan_by_packing_slip' => true, 'return_to_orders' => false, 'click_scan' => false, 'scanning_sequence' => 'any_sequence', 'click_scan_barcode' => 'CLICKSCAN', 'scanned' => false, 'scanned_barcode' => 'SCANNED', 'post_scanning_option_second' => 'None', 'require_serial_lot' => false, 'valid_prefixes' => nil, 'replace_gp_code' => true, 'single_item_order_complete_msg' => 'Labels Printing!', 'single_item_order_complete_msg_time' => 4, 'multi_item_order_complete_msg' => 'Collect all items from the tote!', 'multi_item_order_complete_msg_time' => 4, 'tote_identifier' => 'Tote', 'show_expanded_shipments' => true, 'tracking_number_validation_enabled' => false, 'tracking_number_validation_prefixes' => nil, 'partial' => false, 'partial_barcode' => 'PARTIAL', 'scan_by_packing_slip_or_shipping_label' => false, 'remove_enabled' => false, 'remove_barcode' => 'REMOVE', 'remove_skipped' => true, 'display_location2' => false, 'display_location3' => false, 'show_tags' => true, 'scan_pack_workflow' => 'default', 'tote_sets' => [] } }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
      expect(ScanPackSetting.first.show_tags).to eq(true)
    end

    it 'Update Settings' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      @user.role.update(edit_general_prefs: true)
      request.accept = 'application/json'
      printing_setting = PrintingSetting.create

      request.accept = 'application/json'
      post :update_settings,
           params: { 'id' => 1, 'inventory_tracking' => false, 'low_inventory_alert_email' => false,
                     'low_inventory_email_address' => '', 'hold_orders_due_to_inventory' => false, 'conf_req_on_notes_to_packer' => 'optional', 'send_email_for_packer_notes' => 'always', 'email_address_for_packer_notes' => 'EAST@RACEFACE.COM', 'created_at' => '2021-06-18T20:08:52.000Z', 'updated_at' => '2021-08-13T07:00:53.000Z', 'default_low_inventory_alert_limit' => 1, 'send_email_on_mon' => false, 'send_email_on_tue' => false, 'send_email_on_wed' => false, 'send_email_on_thurs' => false, 'send_email_on_fri' => false, 'send_email_on_sat' => false, 'send_email_on_sun' => false, 'time_to_send_email' => 'Fri Aug 13 2021 00:00:00 ', 'product_weight_format' => 'lb', 'packing_slip_size' => '8.5 x 11', 'packing_slip_orientation' => 'portrait', 'packing_slip_message_to_customer' => nil, 'import_orders_on_mon' => false, 'import_orders_on_tue' => false, 'import_orders_on_wed' => false, 'import_orders_on_thurs' => false, 'import_orders_on_fri' => false, 'import_orders_on_sat' => false, 'import_orders_on_sun' => false, 'time_to_import_orders' => 'Fri Aug 13 2021 00:00:00 ', 'scheduled_order_import' => false, 'tracking_error_order_not_found' => nil, 'tracking_error_info_not_found' => nil, 'strict_cc' => false, 'conf_code_product_instruction' => 'optional', 'admin_email' => nil, 'export_items' => 'standard_order_export', 'custom_field_one' => 'Cust_PO', 'custom_field_two' => 'eComm_Order', 'max_time_per_item' => 10, 'export_csv_email' => 'east@raceface.com', 'show_primary_bin_loc_in_barcodeslip' => false, 'search_by_product' => false, 'time_zone' => '-28799', 'auto_detect' => false, 'dst' => false, 'stat_status' => 'completed', 'cost_calculator_url' => '/cost_calculator?avg_comm=2&avg_current_order=30&avg_error=2&avg_order_profit=0&avg_product_abandonment=6&cancel_order_shipment=1.8&cost_apology=2&cost_confirm=0.25&cost_header=++++++++++++Modify+the+estimates+below+to+match+your+costs+and+see+what+your+company+is+currently+spending+on+errors.++++++++++++&cost_labor_reshipment=0.2&cost_recieving_process=.20&cost_return=0&cost_ship_replacement=3.25&email_text=Hi+Guys%252C+Looks+like+we+are+spending+about+%2524+each+month+on+shipping+errors.+Please+follow+the+link+below+to+see+the+details+of+this+estimate.+You+can+adjust+any+of+the+inputs+to+refine+the+calculation.&error_cost_per_day=119.55&error_per_day=10.8&escalated_comm=3&escalated_percentage=20&expedited_avg=25&expedited_count=40&expedited_percentage=2.5&format=json&from_app=true&gp_cost=200&incorrect_current_order=15&incorrect_current_order_per=6.67&incorrect_lifetime_order=40&incorrect_lifetime_order_per=2.5&intangible_cost=6&international_count=15&international_percentage=0&inventory_shortage=0.9&inventory_shortage_order=30&inventory_shortage_order_per=3.33&lifetime_order_val=5&lifetime_val=250&misc_cost=0&monthly_saving=3386.50&monthly_shipping=3586.50&negative_post_review=0&negative_shipment=150&negative_shipment_per=1&only_save=true&order_count=65&packer_count=4&product_abandonment_percentage=40&recipient_name=undefined&regular_comm=0.45&regular_percentage=80&reshipment=2.50&return_shipment_or_abandonment=2.24&return_shipping_cost=6&return_shipping_insurance=0&return_shipping_percentage=20&total_cost=22.99&total_error_shipment=35&total_expedited=0.63&total_international=2&total_replacement_costs=8.83', 'schedule_import_mode' => nil, 'master_switch' => true, 'html_print' => true, 'idle_timeout' => 240, 'hex_barcode' => false, 'from_import' => '2000-01-01 00:00:00.000', 'to_import' => '2000-01-01 23:59:00.000', 'multi_box_shipments' => true, 'per_box_packing_slips' => 'when_new_boxes_are_started', 'custom_user_field_one' => nil, 'custom_user_field_two' => nil, 'email_address_for_billing_notification' => 'YVESC@RACEFACE.COM', 'display_kit_parts' => false, 'remove_order_items' => true, 'create_barcode_at_import' => false, 'print_post_scanning_barcodes' => false, 'print_packing_slips' => false, 'print_ss_shipping_labels' => false, 'per_box_shipping_label_creation' => 'per_box_shipping_label_creation_none', 'barcode_length' => 8, 'starting_value' => '10000000', 'show_sku_in_barcodeslip' => true, 'print_product_barcode_labels' => false, 'packing_type' => nil, 'product_barcode_label_size' => '2 x 1', 'is_multi_box' => false, 'direct_printing_options' => false, 'ss_api_create_label' => false, 'api_call' => false, 'allow_rts' => false, 'groovelytic_stat' => false, 'product_activity' => false, 'custom_product_fields' => false, 'time_zones' => { 'time_zones' => { "(GMT+13:00) Tonga Standard Time (Nuku'alofa)" => 46_801, '(GMT+12:00) New Zealand Standard Time (Auckland, Wellington)' => 43_201, '(GMT+12:00) Fiji Islands Standard Time (Fiji Islands)' => 43_202, '(GMT+11:00) Central Pacific Standard Time (Solomon Islands)' => 39_601, '(GMT+10:00) West Pacific Standard Time (Guam, Port Moresby)' => 36_001, '(GMT+10:00) Vladivostok Standard Time (Vladivostok)' => 36_002, '(GMT+10:00) Tasmania Standard Time (Hobart)' => 36_003, '(GMT+10:00) E. Australia Standard Time (Brisbane)' => 36_004, '(GMT+10:00) A.U.S. Eastern Standard Time (Canberra, Melbourne, Sydney)' => 36_005, '(GMT+09:30) Cen. Australia Standard Time (Adelaide)' => 34_201, '(GMT+09:30) A.U.S. Central Standard Time (Darwin)' => 34_202, '(GMT+09:00) Yakutsk Standard Time (Yakutsk)' => 32_401, '(GMT+09:00) Tokyo Standard Time  (Osaka, Sapporo, Tokyo)' => 32_402, '(GMT+09:00) Korea Standard Time  (Seoul)' => 32_403, '(GMT+08:00) North Asia East Standard Time (Irkutsk, Ulaanbaatar)' => 28_801, '(GMT+08:00) W. Australia Standard Time (Perth)' => 28_802, '(GMT+08:00) Taipei Standard Time (Taipei)' => 28_803, '(GMT+08:00) Singapore Standard Time  (Kuala Lumpur, Singapore)' => 28_804, '(GMT+08:00) China Standard Time (Beijing, Hong Kong SAR)' => 28_805, '(GMT+07:00) North Asia Standard Time (Krasnoyarsk)' => 25_201, '(GMT+07:00) S.E. Asia Standard Time (Bangkok, Hanoi, Jakarta)' => 25_202, '(GMT+06:30) Myanmar Standard Time (Yangon Rangoon)' => 23_401, '(GMT+06:00) N. Central Asia Standard Time (Almaty, Novosibirsk)' => 21_602, '(GMT+06:00) Sri Lanka Standard Time  Sri (Jayawardenepura)' => 21_603, '(GMT+06:00) Central Asia Standard Time (Astana, Dhaka)' => 21_604, '(GMT+05:45) Nepal Standard Time  (Kathmandu)' => 20_701, '(GMT+05:30) India Standard Time  (Chennai, Kolkata, Mumbai, New Delhi)' => 19_801, '(GMT+05:00) West Asia Standard Time (Islamabad, Karachi, Tashkent)' => 18_001, '(GMT+05:00) Ekaterinburg Standard Time (Ekaterinburg)' => 18_002, '(GMT+04:30) Transitional Islamic State of Afghanistan Standard Time (Kabul)' => 16_201, '(GMT+04:00) Caucasus Standard Time (Baku, Tbilisi, Yerevan)' => 14_402, '(GMT+04:00) Arabian Standard Time (Abu Dhabi, Muscat)' => 14_403, '(GMT+03:30) Iran Standard Time (Tehran)' => 12_601, '(GMT+03:00) Arabic Standard Time (Baghdad)' => 10_802, '(GMT+03:00) E. Africa Standard Time  (Nairobi)' => 10_803, '(GMT+03:00) Arab Standard Time (Kuwait, Riyadh)' => 10_804, '(GMT+03:00) Russian Standard Time (Moscow, St. Petersburg, Volgograd)' => 10_805, '(GMT+02:00) South Africa Standard Time (Harare, Pretoria)' => 7201, '(GMT+02:00) Israel Standard Time (Jerusalem)' => 7202, '(GMT+02:00) GTB Standard Time (Athens, Istanbul, Minsk)' => 7203, '(GMT+02:00) FLE Standard Time (Helsinki, Kiev, Riga, Sofia, Tallinn, Vilnius)' => 7204, '(GMT+02:00) Egypt Standard Time (Cairo)' => 7205, '(GMT+02:00) E. Europe Standard Time  (Bucharest)' => 7206, '(GMT+01:00) W. Central Africa Standard Time  (West Central Africa)' => 3601, '(GMT+01:00) W. Europe Standard Time (Amsterdam, Berlin, Rome)' => 3602, '(GMT+01:00) Romance Standard Time (Brussels, Copenhagen, Madrid, Paris)' => 3603, '(GMT+01:00) Central European Standard Time (Sarajevo, Warsaw)' => 3604, '(GMT+01:00) Central Europe Standard Time (Belgrade, Budapest, Prague)' => 3605, '(GMT+00:00) Greenwich Standard Time  (Casablanca, Monrovia)' => 1, '(GMT+00:00) GMT Standard Time (London)' => 2, '(GMT-01:00) Cape Verde Standard Time (Cape Verde Islands)' => -3599, '(GMT-01:00) Azores Standard Time (Azores)' => -3598, '(GMT-02:00) Mid-Atlantic Standard Time (Mid-Atlantic)' => -7199, '(GMT-03:00) Greenland Standard Time  (Greenland)' => -10_799, '(GMT-03:00) S.A. Eastern Standard Time (Buenos Aires, Georgetown)' => -10_798, '(GMT-03:00) E. South America Standard Time (Brasilia)' => -10_797, '(GMT-03:30) Newfoundland and Labrador Standard Time (Newfoundland)' => -8999, '(GMT-04:00) Pacific S.A. Standard Time (Santiago)' => -14_399, '(GMT-04:00) S.A. Western Standard Time (Caracas, La Paz)' => -14_398, '(GMT-04:00) Atlantic Standard Time (Atlantic Time (Canada))' => -14_397, '(GMT-05:00) S.A. Pacific Standard Time (Bogota, Lima, Quito)' => -17_999, '(GMT-05:00) U.S. Eastern Standard Time (Indiana)' => -17_998, '(GMT-05:00) Eastern Standard Time (Eastern Time (US and Canada))' => -17_997, '(GMT-06:00) Central America Standard Time (Central America)' => -21_599, '(GMT-06:00) Mexico Standard Time (Guadalajara, Mexico City, Monterrey)' => -21_598, '(GMT-06:00) Canada Central Standard Time (Saskatchewan)' => -21_597, '(GMT-06:00) Central Standard Time (Central Time (US and Canada))' => -21_596, '(GMT-07:00) U.S. Mountain Standard Time (Arizona)' => -25_199, '(GMT-07:00) Mexico Standard Time 2 (Chihuahua, La Paz, Mazatlan)' => -25_198, '(GMT-07:00) Mountain Standard Time (Mountain Time (US and Canada))' => -25_197, '(GMT-08:00) Pacific Standard Time (Pacific Time (US and Canada), Tijuana)' => -28_799, '(GMT-09:00) Alaskan Standard Time (Alaska)' => -32_399, '(GMT-10:00) Hawaiian Standard Time (Hawaii)' => -35_999, '(GMT-11:00) Samoa Standard Time  (Midway Island, Samoa)' => -39_599 } }, 'current_time' => '01:47 AM', 'scheduled_import_toggle' => false, 'scan_pack_workflow' => 'default', 'daily_packed_toggle' => false, 'setting' => { 'id' => 1, 'inventory_tracking' => false, 'low_inventory_alert_email' => false, 'low_inventory_email_address' => '', 'hold_orders_due_to_inventory' => false, 'conf_req_on_notes_to_packer' => 'optional', 'send_email_for_packer_notes' => 'always', 'email_address_for_packer_notes' => 'EAST@RACEFACE.COM', 'created_at' => '2021-06-18T20:08:52.000Z', 'updated_at' => '2021-08-13T07:00:53.000Z', 'default_low_inventory_alert_limit' => 1, 'send_email_on_mon' => false, 'send_email_on_tue' => false, 'send_email_on_wed' => false, 'send_email_on_thurs' => false, 'send_email _on_fri' => false, 'send_email_on_sat' => false, 'send_email_on_sun' => false, 'time_to_send_email' => 'Fri Aug 13 2021 00:00:00 ', 'product_weight_format' => 'lb', 'packing_slip_size' => '8.5 x 11', 'packing_slip_orientation' => 'portrait', 'packing_slip_message_to_customer' => nil, 'import_orders_on_mon' => false, 'import_orders_on_tue' => false, 'import_orders_on_wed' => false, 'import_orders_on_thurs' => false, 'import_orders_on_fri' => false, 'import_orders_on_sat' => false, 'import_orders_on_sun' => false, 'time_to_import_orders' => 'Fri Aug 13 2021 00:00:00 ', 'scheduled_order_import' => false, 'tracking_error_order_not_found' => nil, 'tracking_error_info_not_found' => nil, 'strict_cc' => false, 'conf_code_product_instruction' => 'optional', 'admin_email' => nil, 'export_items' => 'standard_order_export', 'custom_field_one' => 'Cust_PO', 'custom_field_two' => 'eComm_Order', 'max_time_per_item' => 10, 'export_csv_email' => 'east@raceface.com', 'show_primary_bin_loc_in_barcodeslip' => false, 'search_by_product' => false, 'time_zone' => '-28799', 'auto_detect' => false, 'dst' => false, 'stat_status' => 'completed', 'cost_calculator_url' => '/cost_calculator?avg_comm=2&avg_current_order=30&avg_error=2&avg_order_profit=0&avg_product_abandonment=6&cancel_order_shipment=1.8&cost_apology=2&cost_confirm=0.25&cost_header=++++++++++++Modify+the+estimates+below+to+match+your+costs+and+see+what+your+company+is+currently+spending+on+errors.++++++++++++&cost_labor_reshipment=0.2&cost_recieving_process=.20&cost_return=0&cost_ship_replacement=3.25&email_text=Hi+Guys%252C+Looks+like+we+are+spending+about+%2524+each+month+on+shipping+errors.+Please+follow+the+link+below+to+see+the+details+of+this+estimate.+You+can+adjust+any+of+the+inputs+to+refine+the+calculation.&error_cost_per_day=119.55&error_per_day=10.8&escalated_comm=3&escalated_percentage=20&expedited_avg=25&expedited_count=40&expedited_percentage=2.5&format=json&from_app=true&gp_cost=200&incorrect_current_order=15&incorrect_current_order_per=6.67&incorrect_lifetime_order=40&incorrect_lifetime_order_per=2.5&intangible_cost=6&international_count=15&international_percentage=0&inventory_shortage=0.9&inventory_shortage_order=30&inventory_shortage_order_per=3.33&lifetime_order_val=5&lifetime_val=250&misc_cost=0&monthly_saving=3386.50&monthly_shipping=3586.50&negative_post_review=0&negative_shipment=150&negative_shipment_per=1&only_save=true&order_count=65&packer_count=4&product_abandonment_percentage=40&recipient_name=undefined&regular_comm=0.45&regular_percentage=80&reshipment=2.50&return_shipment_or_abandonment=2.24&return_shipping_cost=6&return_shipping_insurance=0&return_shipping_percentage=20&total_cost=22.99&total_error_shipment=35&total_expedited=0.63&total_international=2&total_replacement_costs=8.83', 'schedule_import_mode' => nil, 'master_switch' => true, 'html_print' => true, 'idle_timeout' => 240, 'hex_barcode' => false, 'from_import' => '2000-01-01 00:00:00.000', 'to_import' => '2000-01-01 23:59:00.000', 'multi_box_shipments' => true, 'per_box_packing_slips' => 'when_new_boxes_are_started', 'custom_user_field_one' => nil, 'custom_user_field_two' => nil, 'email_address_for_billing_notification' => 'YVESC@RACEFACE.COM', 'display_kit_parts' => false, 'remove_order_items' => true, 'create_barcode_at_import' => false, 'print_post_scanning_barcodes' => false, 'print_packing_slips' => false, 'print_ss_shipping_labels' => false, 'per_box_shipping_label_creation' => 'per_box_shipping_label_creation_none', 'barcode_length' => 8, 'starting_value' => '10000000', 'show_sku_in_barcodeslip' => true, 'print_product_barcode_labels' => false, 'packing_type' => nil, 'product_barcode_label_size' => '1.5 x 1', 'is_multi_box' => false, 'direct_printing_options' => false, 'ss_api_create_label' => false, 'api_call' => false, 'allow_rts' => false, 'groovelytic_stat' => false, 'product_activity' => false, 'custom_product_fields' => false, 'time_zones' => { 'time_zones' => { "(GMT+13:00) Tonga Standard Time (Nuku'alofa)" => 46_801, '(GMT+12:00) New Zealand Standard Time (Auckland, Wellington)' => 43_201, '(GMT+12:00) Fiji Islands Standard Time (Fiji Islands)' => 43_202, '(GMT+11:00) Central Pacific Standard Time (Solomon Islands)' => 39_601, '(GMT+10:00) West Pacific Standard Time (Guam, Port Moresby)' => 36_001, '(GMT+10:00) Vladivostok Standard Time (Vladivostok)' => 36_002, '(GMT+10:00) Tasmania Standard Time (Hobart)' => 36_003, '(GMT+10:00) E. Australia Standard Time (Brisbane)' => 36_004, '(GMT+10:00) A.U.S. Eastern Standard Time (Canberra, Melbourne, Sydney)' => 36_005, '(GMT+09:30) Cen. Australia Standard Time (Adelaide)' => 34_201, '(GMT+09:30) A.U.S. Central Standard Time (Darwin)' => 34_202, '(GMT+09:00) Yakutsk Standard Time (Yakutsk)' => 32_401, '(GMT+09:00) Tokyo Standard Time  (Osaka, Sapporo, Tokyo)' => 32_402, '(GMT+09:00) Korea Standard Time  (Seoul)' => 32_403, '(GMT+08:00) North Asia East Standard Time (Irkutsk, Ulaanbaatar)' => 28_801, '(GMT+08:00) W. Australia Standard Time (Perth)' => 28_802, '(GMT+08:00) Taipei Standard Time (Taipei)' => 28_803, '(GMT+08:00) Singapore Standard Time  (Kuala Lumpur, Singapore)' => 28_804, '(GMT+08:00) China Standard Time (Beijing, Hong Kong SAR)' => 28_805, '(GMT+07:00) North Asia Standard Time (Krasnoyarsk)' => 25_201, '(GMT+07:00) S.E. Asia Standard Time (Bangkok, Hanoi, Jakarta)' => 25_202, '(GMT+06:30) Myanmar Standard Time (Yangon Rangoon)' => 23_401, '(GMT+06:00) N. Central Asia Standard Time (Almaty, Novosibirsk)' => 21_602, '(GMT+06:00) Sri Lanka Standard Time  Sri (Jayawardenepura)' => 21_603, '(GMT+06:00) Central Asia Standard Time (Astana, Dhaka)' => 21_604, '(GMT+05:45) Nepal Standard Time  (Kathmandu)' => 20_701, '(GMT+05:30) India Standard Time  (Chennai, Kolkata, Mumbai, New Delhi)' => 19_801, '(GMT+05:00) West Asia Standard Time (Islamabad, Karachi, Tashkent)' => 18_001, '(GMT+05:00) Ekaterinburg Standard Time (Ekaterinburg)' => 18_002, '(GMT+04:30) Transitional Islamic State of Afghanistan Standard Time (Kabul)' => 16_201, '(GMT+04:00) Caucasus Standard Time (Baku, Tbilisi, Yerevan)' => 14_402, '(GMT+04:00) Arabian Standard Time (Abu Dhabi, Muscat)' => 14_403, '(GMT+03:30) Iran Standard Time (Tehran)' => 12_601, '(GMT+03:00) Arabic Standard Time (Baghdad)' => 10_802, '(GMT+03:00) E. Africa Standard Time  (Nairobi)' => 10_803, '(GMT+03:00) Arab Standard Time (Kuwait, Riyadh)' => 10_804, '(GMT+03:00) Russian Standard Time (Moscow, St. Petersburg, Volgograd)' => 10_805, '(GMT+02:00) South Africa Standard Time (Harare, Pretoria)' => 7201, '(GMT+02:00) Israel Standard Time (Jerusalem)' => 7202, '(GMT+02:00) GTB Standard Time (Athens, Istanbul, Minsk)' => 7203, '(GMT+02:00) FLE Standard Time (Helsinki, Kiev, Riga, Sofia, Tallinn, Vilnius)' => 7204, '(GMT+02:00) Egypt Standard Time (Cairo)' => 7205, '(GMT+02:00) E. Europe Standard Time  (Bucharest)' => 7206, '(GMT+01:00) W. Central Africa Standard Time  (West Central Africa)' => 3601, '(GMT+01:00) W. Europe Standard Time (Amsterdam, Berlin, Rome)' => 3602, '(GMT+01:00) Romance Standard Time (Brussels, Copenhagen, Madrid, Paris)' => 3603, '(GMT+01:00) Central European Standard Time (Sarajevo, Warsaw)' => 3604, '(GMT+01:00) Central Europe Standard Time (Belgrade, Budapest, Prague)' => 3605, '(GMT+00:00) Greenwich Standard Time  (Casablanca, Monrovia)' => 1, '(GMT+00:00) GMT Standard Time (London)' => 2, '(GMT-01:00) Cape Verde Standard Time (Cape Verde Islands)' => -3599, '(GMT-01:00) Azores Standard Time (Azores)' => -3598, '(GMT-02:00) Mid-Atlantic Standard Time (Mid-Atlantic)' => -7199, '(GMT-03:00) Greenland Standard Time  (Greenland)' => -10_799, '(GMT-03:00) S.A. Eastern Standard Time (Buenos Aires, Georgetown)' => -10_798, '(GMT-03:00) E. South America Standard Time (Brasilia)' => -10_797, '(GMT-03:30) Newfoundland and Labrador Standard Time (Newfoundland)' => -8999, '(GMT-04:00) Pacific S.A. Standard Time (Santiago)' => -14_399, '(GMT-04:00) S.A. Western Standard Time (Caracas, La Paz)' => -14_398, '(GMT-04:00) Atlantic Standard Time (Atlantic Time (Canada))' => -14_397, '(GMT-05:00) S.A. Pacific Standard Time (Bogota, Lima, Quito)' => -17_999, '(GMT-05:00) U.S. Eastern Standard Time (Indiana)' => -17_998, '(GMT-05:00) Eastern Standard Time (Eastern Time (US and Canada))' => -17_997, '(GMT-06:00) Central America Standard Time (Central America)' => -21_599, '(GMT-06:00) Mexico Standard Time (Guadalajara, Mexico City, Monterrey)' => -21_598, '(GMT-06:00) Canada Central Standard Time (Saskatchewan)' => -21_597, '(GMT-06:00) Central Standard Time (Central Time (US and Canada))' => -21_596, '(GMT-07:00) U.S. Mountain Standard Time (Arizona)' => -25_199, '(GMT-07:00) Mexico Standard Time 2 (Chihuahua, La Paz, Mazatlan)' => -25_198, '(GMT-07:00) Mountain Standard Time (Mountain Time (US and Canada))' => -25_197, '(GMT-08:00) Pacific Standard Time (Pacific Time (US and Canada), Tijuana)' => -28_799, '(GMT-09:00) Alaskan Standard Time (Alaska)' => -32_399, '(GMT-10:00) Hawaiian Standard Time (Hawaii)' => -35_999, '(GMT-11:00) Samoa Standard Time  (Midway Island, Samoa)' => -39_599 } }, 'current_time' => '01:47 AM', 'scheduled_import_toggle' => false, 'scan_pack_workflow' => 'default', 'daily_packed_toggle' => false } }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
      expect(PrintingSetting.last.product_barcode_label_size).to eq('2 x 1')
    end

    it 'Get Settings' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      @user.role.update(edit_general_prefs: true)
      request.accept = 'application/json'
      printing_setting = PrintingSetting.create
      post :get_settings, params: { "app": true }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
      expect(JSON.parse(response.body)['data']['settings']['inventory_tracking']).to eq(true)

      request.accept = 'application/json'
      post :get_settings

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
      expect(JSON.parse(response.body)['data']['settings']['product_barcode_label_size']).to eq('3 x 1')
    end

    it 'get Scan Pack Settings' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      @user.role.update(edit_scanning_prefs: true)
      request.accept = 'application/json'
      post :get_scan_pack_settings, params: { "app": true }
      scan_pack_setting = ScanPackSetting.create
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
    end

    it 'get Scan Pack  & General Settings for Expo' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      @user.role.update(edit_general_prefs: true)
      @user.role.update(edit_scanning_prefs: true)
      request.accept = 'application/json'
      get :get_setting, params: { "app": true }
      scan_pack_setting = ScanPackSetting.create
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
    end

    it 'Serial export report should be working' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      @user.role.update(edit_general_prefs: true)
      @user.role.update(edit_scanning_prefs: true)
      @user.role.update(view_packing_ex: true)
      request.accept = 'application/json'
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      OrderSerial.create(
        order_id: @order.id,
        product_id: product.id,
        serial: 'ABC123',
        second_serial: 'XYZ456',
        updated_at: 'Fri, 25 Apr 2024 08:03:37'
      )
      get :order_serials,
          params: { "app": true, "start": 'Sun Jan 01 2023 16:08:35', "end": 'Fri Apr 26 2024 16:08:35' }
      scan_pack_setting = ScanPackSetting.create
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
    end

    it 'update time zone' do
      @user.role.update(edit_general_prefs: true)
      @tenant = Tenant.create(name: Apartment::Tenant.current)
      request.accept = 'application/json'
      post :fetch_and_update_time_zone, params: { add_time_zone: 2, dst: false, new_time_zone: 'UTC' }
      expect(response.status).to eq(200)
    end

    it 'update auto time zone' do
      @user.role.update(edit_general_prefs: true)
      @tenant = Tenant.create(name: Apartment::Tenant.current)
      request.accept = 'application/json'
      post :update_auto_time_zone, params: { offset: 330 }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
    end

    it 'Update Stat Status' do
      @tenant = Tenant.create(name: Apartment::Tenant.current)
      request.accept = 'application/json'
      post :update_stat_status, params: { percentage: 100 }
      expect(response.status).to eq(200)
    end
  end

  describe 'Basic Functions' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)

      allow(controller).to receive(:doorkeeper_token) { token1 }
      allow(token1).to receive(:id).and_return(nil)
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    context 'POST #update_packing_cam_image' do
      it 'success' do
        post :update_packing_cam_image, params: { image: fixture_file_upload('../logo.png'), type: 'email_logo' }
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['status']).to be_truthy
      end

      it 'fails' do
        post :update_packing_cam_image, params: { image: fixture_file_upload('../logo.png'), type: 'semail_logo' }
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['status']).to be_falsy
      end
    end
  end

  describe 'Restore Products' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
      allow(controller).to receive(:doorkeeper_token) { token1 }
      allow(token1).to receive(:id).and_return(nil)
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Restore Products from file' do
      request.accept = 'application/json'

      post :restore, params: { file: fixture_file_upload('spec/fixtures/files/groove-export.zip') }
      expect(response.status).to eq(200)
    end
  end
end
