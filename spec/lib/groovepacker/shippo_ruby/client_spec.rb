require 'rails_helper'

RSpec.describe Groovepacker::ShippoRuby::Client do
  before do
    Groovepacker::SeedTenant.new.seed
    tenant = Apartment::Tenant.current
    Apartment::Tenant.switch!(tenant.to_s)
    @tenant = Tenant.create(name: tenant.to_s)
    store =  FactoryBot.create(:store, inventory_warehouse_id: InventoryWarehouse.last.id, store_type: 'Shippo')
    @shippo_credential = FactoryBot.create(:shippo_credential, store_id: store.id, last_imported_at: '2021-03-15 23:52:17')
  end
    
  describe '#orders' do
    it 'get orders' do
      importer = described_class.new(@shippo_credential)
      expect(importer.send(:orders)['orders']).not_to be_nil
    end
    
    it 'get ranged orders' do
      importer = described_class.new(@shippo_credential)
      expect(importer.send(:get_ranged_orders, '2021-03-15 23:52:17', '2021-03-20 23:52:17')['orders']).not_to be_nil
    end
  end
end