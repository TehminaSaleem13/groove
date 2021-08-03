require 'rails_helper'

RSpec.describe ExportsettingsController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    inv_wh = FactoryBot.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
    @store = FactoryBot.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>inv_wh, :status => true)
    access_restriction = FactoryBot.create(:access_restriction)
  end

  describe 'Exportsettings' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Export Order' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!("#{tenant}")
      @tenant = Tenant.create(name: "#{tenant}")
    #   ExportSetting.create(auto_email_export: true, time_to_send_export_email: "2021-08-02 06:00:00", send_export_email_on_mon: true, send_export_email_on_tue: true, send_export_email_on_wed: false, send_export_email_on_thu: false, send_export_email_on_fri: false, send_export_email_on_sat: false, send_export_email_on_sun: false, last_exported: "2021-08-02 13:47:07", export_orders_option: "since_last_export", order_export_type: "include_all", order_export_email: "YVESC@RACEFACE.COM", created_at: "2021-06-18 20:08:52", updated_at: "2021-08-02 13:17:48", start_time: "2021-08-02 18:47:41", end_time: "2021-08-02 18:47:41", manual_export: true, auto_stat_email_export: true, time_to_send_stat_export_email: "2021-08-02 16:00:00", send_stat_export_email_on_mon: false, send_stat_export_email_on_tue: false, send_stat_export_email_on_wed: false, send_stat_export_email_on_thu: false, send_stat_export_email_on_fri: false, send_stat_export_email_on_sat: false, send_stat_export_email_on_sun: false, stat_export_type: "1", stat_export_email: nil, processing_time: 0, daily_packed_email_export: false, time_to_send_daily_packed_export_email: "2021-08-02 16:00:00", daily_packed_email_on_mon: false, daily_packed_email_on_tue: false, daily_packed_email_on_wed: false, daily_packed_email_on_thu: false, daily_packed_email_on_fri: false, daily_packed_email_on_sat: false, daily_packed_email_on_sun: false, daily_packed_export_type: "30", daily_packed_email: nil, auto_ftp_export: false)
      request.accept = 'application/json'
    #   binding.pry
      order = Order.create(increment_id: "C000209814-B(Duplicate-2)", order_placed_time: "1776-07-04 00:00:00", sku: nil, customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: "BIKE", lastname: "ACTIONGmbH", email: "east@raceface.com", address_1: "WEISKIRCHER STR. 102", address_2: nil, city: "RODGAU", state: nil, postcode: "63110", country: "GERMANY", method: nil, created_at: "2021-08-02 09:07:21", updated_at: "2021-08-02 10:14:55", notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: "scanned", scanned_on: "2021-08-02 10:14:55", tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: "C000209814B(Duplicate2)", note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: "2021-08-02 09:48:56", reallocate_inventory: false, last_suggested_at: "2021-08-02 10:14:55", total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: "orders/2021-07-29-162759275061.xml", last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: "", ss_label_data: nil, importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product = Product.create(store_product_id: "0", name: "TRIGGER SS JERSEY-BLACK-M", product_type: "", store_id: @store.id, created_at: "2021-06-18 20:58:12", updated_at: "2021-07-30 19:31:32", status: "active", packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: "individual", is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: "on", click_scan_enabled: "on", weight_format: "oz", add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: "", custom_product_2: "", custom_product_3: "", custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: "821973374048", isbn: nil, ean: "0821973374048", supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, created_at: "2021-08-02 10:13:54", updated_at: "2021-08-02 10:14:28", name: "TRIGGER SS JERSEY-BLACK-M", product_id: product.id, scanned_status: "scanned", scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: "unprocessed", inv_status_reason: "", clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      box = Box.create(name: "Box 1",order_id: order.id)
      OrderItemBox.create(box_id: box.id, order_item_id: order_item.id, item_qty: 1, kit_id: nil)
      ExportSetting.last.update(order_export_type: "include_all")
      @user.role.update(view_packing_ex: true)
      get :order_exports, params: {"start"=>"Mon Aug 02 2021 18:47:41 GMT 0530 (India Standard Time)", "end"=>"Mon Aug 02 2021 18:47:41 GMT 0530 (India Standard Time)"}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
      @tenant.destroy
    end
  end 
end    