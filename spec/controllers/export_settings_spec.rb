require 'rails_helper'

RSpec.describe ExportsettingsController, type: :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role, name: 'super_admin1', make_super_admin: true)
    @user = FactoryGirl.create(:user, username: 'new_admin1', role: sup_ad, name: 'testing')
    sign_in @user
    @inv_wh = FactoryGirl.create(:inventory_warehouse, is_default: true)
  end

  describe 'Export settings' do 

    context 'get export settings' do
      it 'Should get the settings for export' do
       request.accept = "application/json"

       general_setting = FactoryGirl.create :general_setting
       export_setting = FactoryGirl.create(:export_setting,  auto_email_export: true, 
        time_to_send_export_email: "2016-07-04 16:52:00", last_exported: "2016-04-07 01:51:44", 
        export_orders_option: "on_same_day", order_export_type: "include_all", 
        order_export_email: "test@example.com", start_time: "2016-07-04 16:41:16", 
        end_time: "2016-07-04 16:41:16", manual_export: false)
       
       get :get_export_settings, {}
       expect(response.status).to eq(200)
       result = JSON.parse(response.body)
     end

     it 'Should get the error for export orders if export settings is nil' do
       request.accept = "application/json"
       error = ["No export settings available for the system. Contact administrator."]
       get :get_export_settings, {}
       expect(response.status).to eq(200)
       result = JSON.parse(response.body)
       expect(result["error_messages"]).to eq(error)
     end
   end

   context 'update export settings' do 
    it 'Should update export settings' do
      request.accept = "application/json"
      general_setting = FactoryGirl.create :general_setting
      export_setting = FactoryGirl.create(:export_setting,  auto_email_export: true, 
        time_to_send_export_email: "2016-07-04 16:52:00",
        export_orders_option: "on_same_day", order_export_type: "include_all", 
        order_export_email: "test@example.com", start_time: "2016-07-04 16:41:16", 
        end_time: "2016-07-04 16:41:16", manual_export: false)

      success = ["Export settings updated successfully."]

      get :update_export_settings, {:auto_email_export=>true, 
        :send_export_email_on_fri=>true, :send_export_email_on_mon=>true, 
        :send_export_email_on_sat=>false, :send_export_email_on_sun=>false, 
        :send_export_email_on_thu=>true, :send_export_email_on_tue=>true, 
        :send_export_email_on_wed=>true}

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result["success_messages"]).to eq(success)
      end

      it 'Should get the error for update export if update export settings fails' do
       request.accept = "application/json"
       error = ["No export settings available for the system. Contact administrator."]
       get :update_export_settings, {}
       expect(response.status).to eq(200)
       result = JSON.parse(response.body)
       expect(result["error_messages"]).to eq(error)
     end

     it 'Should get the error for update export if un-authorised user' do   
      sign_out @user
      subject.current_user.should be_nil
      @user_role_new = FactoryGirl.create(:role, :name=>'ebay_spec_tester_role')
      @user_new = FactoryGirl.create(:user, :name=>'Ebay Tester', :username=>"ebay_spec_tester", confirmation_code: "1234567891", :role => @user_role_new)
      sign_in @user_new
      @access_restriction = FactoryGirl.create(:access_restriction)

      general_setting = FactoryGirl.create :general_setting
      export_setting = FactoryGirl.create(:export_setting,  auto_email_export: true, 
        time_to_send_export_email: "2016-07-04 16:52:00",
        export_orders_option: "on_same_day", order_export_type: "include_all", 
        order_export_email: "test@example.com", start_time: "2016-07-04 16:41:16", 
        end_time: "2016-07-04 16:41:16", manual_export: false)

      request.accept = "application/json"
      error = ["You are not authorized to update export preferences."]
      get :update_export_settings, {}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["error_messages"]).to eq(error)
    end
  end

  context 'order export' do
    it 'Should export orders' do
      request.accept = "application/json"

      general_setting = FactoryGirl.create :general_setting
      export_setting = FactoryGirl.create(:export_setting,  auto_email_export: true, 
        time_to_send_export_email: "2016-07-04 16:52:00",
        export_orders_option: "on_same_day", order_export_type: "include_all", 
        order_export_email: "test@example.com", start_time: "2016-07-04 16:41:16", 
        end_time: "2016-07-04 16:41:16", manual_export: false)

      get :order_exports, {:start=>"Tue Jul 05 2016 12:58:40 GMT 0530 (IST)", :end=>"Tue Jul 05 2016 12:58:40 GMT 0530 (IST)"} 
      expect(response.status).to eq(200)

      filename = File.new("#{Rails.root}/public/csv/" + export_setting.export_data, "w+")
      open("#{Rails.root}/public/csv/" + export_setting.export_data, "w+") do |f|
        f << response.body.chomp
      end
      content = File.read("#{Rails.root}/public/csv/" + export_setting.export_data)
      expect(content).to have_content("order_date,order_number,barcode,primary_sku,product_name,packing_user,order_item_count,scanned_date,warehouse_name,item_sale_price,kit_name,customer_name,address1,address2,city,state,zip")
      File.delete("#{Rails.root}/public/csv/" + export_setting.export_data)
    end

    it 'Should display error message when no start and end date is passed' do
      request.accept = "application/json"

      general_setting = FactoryGirl.create :general_setting
      export_setting = FactoryGirl.create(:export_setting,  auto_email_export: true, 
        time_to_send_export_email: "2016-07-04 16:52:00",
        export_orders_option: "on_same_day", order_export_type: "include_all", 
        order_export_email: "test@example.com", manual_export: false)

      message = ["We need a start and an end time"]

      get :order_exports, {:start=> nil, :end=> nil} 
      expect(response.status).to eq(200)
      filename = File.new("#{Rails.root}/public/csv/error.csv", "w+")
      open("#{Rails.root}/public/csv/error.csv", "w+") do |f|
        f << response.body.chomp
      end
      content = File.read("#{Rails.root}/public/csv/error.csv")
      expect(content).to have_content("We need a start and an end time")
      File.delete("#{Rails.root}/public/csv/error.csv")
    end

  end

end

end