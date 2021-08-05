require 'rails_helper'

RSpec.describe SettingsController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    access_restriction = FactoryBot.create(:access_restriction)
    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    @store = FactoryBot.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true)
    csv_mapping = FactoryBot.create(:csv_mapping, store_id: @store.id)
  end

  after :each do
    @tenant.destroy
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
      Apartment::Tenant.switch!("#{tenant}")
      @tenant = Tenant.create(name:"#{tenant}")
      @user.role.update(edit_scanning_prefs: true)
      request.accept = 'application/json'
      binding.pry
      post :update_scan_pack_settings, params: {"id"=>1, "enable_click_sku"=>true, "ask_tracking_number"=>false, "created_at"=>"2021-07-28T12:57:11.000Z", "updated_at"=>"2021-08-05T08:53:56.000Z", "show_success_image"=>true, "success_image_src"=>"/assets/images/scan_success.png", "success_image_time"=>0.5, "show_fail_image"=>true, "fail_image_src"=>"/assets/images/scan_fail.png", "fail_image_time"=>1, "play_success_sound"=>true, "success_sound_url"=>"/assets/sounds/scan_success.mp3", "success_sound_vol"=>0.75, "play_fail_sound"=>true, "fail_sound_url"=>"/assets/sounds/scan_fail.mp3", "fail_sound_vol"=>0.75, "skip_code_enabled"=>true, "skip_code"=>"SKIP", "note_from_packer_code_enabled"=>true, "note_from_packer_code"=>"NOTE", "service_issue_code_enabled"=>true, "service_issue_code"=>"ISSUE", "restart_code_enabled"=>true, "restart_code"=>"RESTART", "show_order_complete_image"=>true, "order_complete_image_src"=>"/assets/images/scan_order_complete.png", "order_complete_image_time"=>1, "play_order_complete_sound"=>true, "order_complete_sound_url"=>"/assets/sounds/scan_order_complete.mp3", "order_complete_sound_vol"=>0.75, "type_scan_code_enabled"=>true, "type_scan_code"=>"*", "post_scanning_option"=>"None", "escape_string"=>" - ", "escape_string_enabled"=>false, "record_lot_number"=>false, "show_customer_notes"=>true, "show_internal_notes"=>true, "scan_by_shipping_label"=>false, "intangible_setting_enabled"=>true, "intangible_string"=>"Coupon:", "post_scan_pause_enabled"=>false, "post_scan_pause_time"=>4, "intangible_setting_gen_barcode_from_sku"=>true, "display_location"=>false, "string_removal_enabled"=>false, "string_removal"=>nil, "first_escape_string_enabled"=>false, "second_escape_string_enabled"=>false, "second_escape_string"=>nil, "order_verification"=>false, "scan_by_packing_slip"=>true, "return_to_orders"=>false, "click_scan"=>false, "scanning_sequence"=>"any_sequence", "click_scan_barcode"=>"CLICKSCAN", "scanned"=>false, "scanned_barcode"=>"SCANNED", "post_scanning_option_second"=>"None", "require_serial_lot"=>false, "valid_prefixes"=>nil, "replace_gp_code"=>true, "single_item_order_complete_msg"=>"Labels Printing!", "single_item_order_complete_msg_time"=>4, "multi_item_order_complete_msg"=>"Collect all items from the tote!", "multi_item_order_complete_msg_time"=>4, "tote_identifier"=>"Tote", "show_expanded_shipments"=>true, "tracking_number_validation_enabled"=>false, "tracking_number_validation_prefixes"=>nil, "partial"=>false, "partial_barcode"=>"PARTIAL", "scan_by_packing_slip_or_shipping_label"=>false, "remove_enabled"=>false, "remove_barcode"=>"REMOVE", "remove_skipped"=>true, "display_location2"=>false, "display_location3"=>false, "show_tags"=>true, "scan_pack_workflow"=>"default", "tote_sets"=>[], "setting"=>{"id"=>1, "enable_click_sku"=>true, "ask_tracking_number"=>false, "created_at"=>"2021-07-28T12:57:11.000Z", "updated_at"=>"2021-08-05T08:53:56.000Z", "show_success_image"=>true, "success_image_src"=>"/assets/images/scan_success.png", "success_image_time"=>0.5, "show_fail_image"=>true, "fail_image_src"=>"/assets/images/scan_fail.png", "fail_image_time"=>1, "play_success_sound"=>true, "success_sound_url"=>"/assets/sounds/scan_success.mp3", "success_sound_vol"=>0.75, "play_fail_sound"=>true, "fail_sound_url"=>"/assets/sounds/scan_fail.mp3", "fail_sound_vol"=>0.75, "skip_code_enabled"=>true, "skip_code"=>"SKIP", "note_from_packer_code_enabled"=>true, "note_from_packer_code"=>"NOTE", "service_issue_code_enabled"=>true, "service_issue_code"=>"ISSUE", "restart_code_enabled"=>true, "restart_code"=>"RESTART", "show_order_complete_image"=>true, "order_complete_image_src"=>"/assets/images/scan_order_complete.png", "order_complete_image_time"=>1, "play_order_complete_sound"=>true, "order_complete_sound_url"=>"/assets/sounds/scan_order_complete.mp3", "order_complete_sound_vol"=>0.75, "type_scan_code_enabled"=>true, "type_scan_code"=>"*", "post_scanning_option"=>"None", "escape_string"=>" - ", "escape_string_enabled"=>false, "record_lot_number"=>false, "show_customer_notes"=>true, "show_internal_notes"=>true, "scan_by_shipping_label"=>false, "intangible_setting_enabled"=>true, "intangible_string"=>"Coupon:", "post_scan_pause_enabled"=>false, "post_scan_pause_time"=>4, "intangible_setting_gen_barcode_from_sku"=>true, "display_location"=>false, "string_removal_enabled"=>false, "string_removal"=>nil, "first_escape_string_enabled"=>false, "second_escape_string_enabled"=>false, "second_escape_string"=>nil, "order_verification"=>false, "scan_by_packing_slip"=>true, "return_to_orders"=>false, "click_scan"=>false, "scanning_sequence"=>"any_sequence", "click_scan_barcode"=>"CLICKSCAN", "scanned"=>false, "scanned_barcode"=>"SCANNED", "post_scanning_option_second"=>"None", "require_serial_lot"=>false, "valid_prefixes"=>nil, "replace_gp_code"=>true, "single_item_order_complete_msg"=>"Labels Printing!", "single_item_order_complete_msg_time"=>4, "multi_item_order_complete_msg"=>"Collect all items from the tote!", "multi_item_order_complete_msg_time"=>4, "tote_identifier"=>"Tote", "show_expanded_shipments"=>true, "tracking_number_validation_enabled"=>false, "tracking_number_validation_prefixes"=>nil, "partial"=>false, "partial_barcode"=>"PARTIAL", "scan_by_packing_slip_or_shipping_label"=>false, "remove_enabled"=>false, "remove_barcode"=>"REMOVE", "remove_skipped"=>true, "display_location2"=>false, "display_location3"=>false, "show_tags"=>true, "scan_pack_workflow"=>"default", "tote_sets"=>[]}}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
      expect(ScanPackSetting.first.show_tags).to eq(true)
    end
  end
end
