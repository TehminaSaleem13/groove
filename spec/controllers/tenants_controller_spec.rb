require 'rails_helper'

RSpec.describe TenantsController, type: :controller do
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

  describe 'Tenant Import Summary' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Delete Import Summary' do
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!("#{tenant}")
      tenant = Tenant.create(name: "#{tenant}")
      
      import_summary = OrderImportSummary.create(user_id: @user.id, status: "in_progress", import_summary_type: "import_orders", display_summary: false)
      order_item =   ImportItem.create(status: "in_progress", store_id: @store.id , success_imported: 4, previous_imported: 0, order_import_summary_id:  import_summary.id, to_import: 226, current_increment_id: "5004716159", current_order_items: 5, current_order_imported_item: 5, message: nil, import_type: "quick", days: nil, updated_orders_import: 0)
      request.accept = 'application/json'

      get :delete_summary, params: {"tenant"=>tenant.id}

      expect(response.status).to eq(200)
      expect(ImportItem.last.status).to eq("cancelled")
      expect(OrderImportSummary.last.status).to eq("cancelled")
      tenant.destroy
    end
  end
end  