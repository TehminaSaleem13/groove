require 'rails_helper'

RSpec.describe UsersController, type: :controller do
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

  describe 'Users' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'User Modify Plan' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!("#{tenant}")
      @tenant = Tenant.create(name: "#{tenant}")
      Subscription.create(email: "zzpeaceout@yahoo.com", tenant_name: tenant , amount: 0.162e6, stripe_user_token: "tok_1J5QhF44KQj1OQ8CHwFNXxg6", status: "completed", tenant_id: @tenant.id, stripe_transaction_identifier: "txn_1J5QhM44KQj1OQ8C8gZjbT6E", created_at: "2021-06-23 07:40:31", updated_at: "2021-06-23 07:41:05", transaction_errors: nil, subscription_plan_id: "an-gpproductionupgrade-150", customer_subscription_id: "sub_JisSpfFXcFBc9d", stripe_customer_id: "cus_JisS4jxhKbeuUc", is_active: true, password: "password", user_name: "test", coupon_id: nil, progress: "transaction_complete", shopify_customer: false, all_charges_paid: false, interval: "year", app_charge_id: nil, tenant_charge_id: nil, shopify_shop_name: nil, tenant_data: nil, shopify_payment_token: nil)
      request.accept = 'application/json'

      get :modify_plan, params: {"users"=>@user.id, "amount"=>"18576", "is_annual"=>"false"}

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(false)
      expect(JSON.parse(response.body)['error_messages']).to eq("Can't Change Yearly Plan to Monthly")
      @tenant.destroy
    end
  end 
end    