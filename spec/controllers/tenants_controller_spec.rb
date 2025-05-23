# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantsController, type: :controller do
  let(:tenant) { Tenant.create(name: Apartment::Tenant.current) }
  let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

  before do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    @store = FactoryBot.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true)
    FactoryBot.create(:access_restriction)

    allow(controller).to receive(:doorkeeper_token) { token1 }
    header = { 'Authorization' => "Bearer #{FactoryBot.create(:access_token, resource_owner_id: @user.id).token}" }
    @request.headers.merge! header
  end

  after do
    tenant.destroy
  end

  describe 'Tenant' do
    it 'Delete Import Summary' do
      import_summary = OrderImportSummary.create(user_id: @user.id, status: 'in_progress',
                                                 import_summary_type: 'import_orders', display_summary: false)
      ImportItem.create(status: 'in_progress', store_id: @store.id, success_imported: 4,
                        previous_imported: 0, order_import_summary_id: import_summary.id, to_import: 226, current_increment_id: '5004716159', current_order_items: 5, current_order_imported_item: 5, message: nil, import_type: 'quick', days: nil, updated_orders_import: 0)
      request.accept = 'application/json'

      get :delete_summary, params: { 'tenant' => tenant.id }

      expect(response.status).to eq(200)
      result = JSON.parse response.body
      expect(result['status']).to be_truthy
    end

    it 'Shopify Unique Import' do
      request.accept = 'application/json'

      get :update_setting, params: { tenant_id: tenant.id, setting: 'uniq_shopify_import' }

      tenant.reload
      expect(tenant.uniq_shopify_import).to eq(true)
    end

    it 'Update GDPR Shipstation' do
      request.accept = 'application/json'
      get :update_setting, params: { tenant_id: tenant.id, setting: 'gdpr_shipstation' }

      tenant.reload
      expect(tenant.gdpr_shipstation).to eq(true)
    end

    it 'Update Price Field' do
      tenant.price = {
        'bigCommerce_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'shopify_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'shopline_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'magento2_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'teapplix_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'product_activity_log_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'magento_soap_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'multi_box_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'amazon_fba_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'post_scanning_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'allow_Real_time_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'import_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'inventory_report_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'custom_product_fields_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'enable_developer_tools_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'high_sku_feature' => { 'toggle' => false, 'amount' => 50, 'stripe_id' => '' },
        'double_high_sku' => { 'toggle' => false, 'amount' => 100, 'stripe_id' => '' },
        'cust_maintenance_1' => { 'toggle' => true, 'amount' => '15', 'stripe_id' => 'si_I4i2XgmVjvWmTR' },
        'cust_maintenance_2' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'groovelytic_stat_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'product_ftp_import' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }
      }
      tenant.save
      request.accept = 'application/json'

      get :update_price_field,
          params: { 'feature' => 'high_sku_feature', 'value' => { 'toggle' => true }, 'id' => tenant.id,
                    'tenant' => {} }

      tenant.reload

      expect(tenant.price['cust_maintenance_1']['toggle']).to eq(true)
    end

    it 'Email Billing Report' do
      Subscription.create(email: 'zzpeaceout@yahoo.com', tenant_name: tenant, amount: 0.162e6,
                          stripe_user_token: 'tok_1J5QhF44KQj1OQ8CHwFNXxg6', status: 'completed', tenant_id: tenant.id, stripe_transaction_identifier: 'txn_1J5QhM44KQj1OQ8C8gZjbT6E', created_at: '2021-06-23 07:40:31', updated_at: '2021-06-23 07:41:05', transaction_errors: nil, subscription_plan_id: 'an-gpproductionupgrade-150', customer_subscription_id: 'sub_JisSpfFXcFBc9d', stripe_customer_id: 'cus_JisS4jxhKbeuUc', is_active: true, password: 'password', user_name: 'test', coupon_id: nil, progress: 'transaction_complete', shopify_customer: false, all_charges_paid: false, interval: 'year', app_charge_id: nil, tenant_charge_id: nil, shopify_shop_name: nil, tenant_data: nil, shopify_payment_token: nil)
      tenant.price = {
        'bigCommerce_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'shopify_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'shopline_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'magento2_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'teapplix_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'product_activity_log_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'magento_soap_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'multi_box_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'amazon_fba_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'post_scanning_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'allow_Real_time_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'import_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'inventory_report_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'custom_product_fields_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'enable_developer_tools_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'high_sku_feature' => { 'toggle' => false, 'amount' => 50, 'stripe_id' => '' },
        'double_high_sku' => { 'toggle' => false, 'amount' => 100, 'stripe_id' => '' },
        'cust_maintenance_1' => { 'toggle' => true, 'amount' => '15', 'stripe_id' => 'si_I4i2XgmVjvWmTR' },
        'cust_maintenance_2' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'groovelytic_stat_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' },
        'product_ftp_import' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }
      }
      tenant.save
      request.accept = 'application/json'

      post :tenant_log
      expect(response.status).to eq(200)
      expect(response.body).to eq('{}')
    end

    it 'Send Bulk Csv' do
      request.accept = 'application/json'

      post :bulk_event_logs, params: { tenant_names: [tenant.name] }
      expect(response.status).to eq(200)
    end

    it 'Update Scan Workflow' do
      request.accept = 'application/json'

      post :update_scan_workflow, params: { tenant_id: tenant.id, workflow: 'default' }
      # post :update_access_restrictions, params: { id: tenant.id, basicinfo: {id: tenant.id, orders_delete_days: 14, is_multi_box: true} }
      # post :update_scheduled_import_toggle, params: { tenant_id: tenant.id }
      # post :clear_all_imports
      expect(response.status).to eq(200)
    end

    it 'Update Access Restriction' do
      request.accept = 'application/json'

      post :update_access_restrictions,
           params: { id: tenant.id, basicinfo: { id: tenant.id, orders_delete_days: 14, is_multi_box: true } }
      expect(response.status).to eq(200)
    end

    it 'Get a single tenant' do
      request.accept = 'application/json'

      get :show, params: { id: tenant.id }
      expect(response.status).to eq(200)
    end

    it 'Update Scheduled Import Toggle' do
      request.accept = 'application/json'

      post :update_scheduled_import_toggle, params: { tenant_id: tenant.id }
      expect(response.status).to eq(200)
    end

    context 'Admintools' do
      it 'fixes corrupt product data' do
        get :fix_product_data, params: { select_all: true }
        expect(response.status).to eq(200)
      end
    end

    it 'Get tenant activity logs' do
      get :list_activity_logs, params: { id: tenant.id, offset: '0', limit: '20', search: '' }
      expect(response.status).to eq(200)
      result = JSON.parse response.body
      expect(result['status']).to eq(true)
    end

    it 'Get search activity logs' do
      get :list_activity_logs, params: { id: tenant.id, offset: '0', limit: '20', search: 'General' }
      expect(response.status).to eq(200)
      result = JSON.parse response.body
      expect(result['status']).to eq(true)
    end
  end

  describe 'POST #clear_all_imports' do
    it 'renders a success message' do
      post :clear_all_imports
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq('status' => 'All import jobs will be stopped shortly')
    end
  end
end
