require 'rails_helper'

RSpec.describe Groovepacker::ShippoRuby::Client do
  before do
    Groovepacker::SeedTenant.new.seed
    tenant = Apartment::Tenant.current
    Apartment::Tenant.switch!(tenant.to_s)
    @tenant = Tenant.create(name: tenant.to_s)
  end
  let(:store) { create(:store, inventory_warehouse_id: InventoryWarehouse.last.id, store_type: 'Shippo') }
    
  describe '#orders' do
    it 'get orders' do
      shippo_credential = FactoryBot.create(:shippo_credential, store_id: store.id, last_imported_at: '2021-03-15 23:52:17')
      importer = described_class.new(shippo_credential)
      expect(importer.send(:orders)['orders']).not_to be_nil
    end
  end
end