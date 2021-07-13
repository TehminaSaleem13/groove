require 'rails_helper'

RSpec.describe SubscriptionsController, type: :controller do
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

  describe 'Subscriptions' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    # it 'Confirm Payment' do
    #   tenant = Apartment::Tenant.current
    #   Apartment::Tenant.switch!("#{tenant}")
    #   @tenant = Tenant.create(name: "#{tenant}")
      
         
    #   request.accept = 'application/json'
    #   post :confirm_payment , params: {"tenant_name"=>tenant, "stripe_user_token"=>"tok_1JCk0q44KQj1OQ8CM9ovm10W", "email"=>"lxzeuso5@connectebay.com", "amount"=>"50000", "plan_id"=>"an-GROOV-150", "user_name"=>"groovetest", "password"=>"[FILTERED]", "radio_subscription"=>"annually", "shop_name"=>"", "shop_type"=>"", "subscription"=>{"email"=>"lxzeuso5@connectebay.com", "tenant_name"=>tenant, "amount"=>"50000", "stripe_user_token"=>"tok_1JCk0q44KQj1OQ8CM9ovm10W", "password"=>"[FILTERED]", "user_name"=>"groovetest"}}
    #   expect(response.status).to eq(200)
    #   @tenant.destroy
    # end

    it 'Validate Tenant Name' do
      tenant = '1234'
    
      request.accept = 'application/json'
      get :valid_tenant_name, params:{"tenant_name"=>tenant}
      expect(response.status).to eq(200)
    end
  end 
end  