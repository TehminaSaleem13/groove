require 'rails_helper'

RSpec.describe Order, type: :model do
  it 'should have unique increament_id' do
    inv_wh = FactoryBot.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
    store = FactoryBot.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>inv_wh, :status => true)
    Order.create(increment_id: '1', store_id: store.id)
    order = Order.new(increment_id: '1', store_id: store.id)
    order.should_not be_valid
    order.errors[:increment_id].should include('has already been taken')
  end

  describe Order do
    it 'order should have many order item' do
      t = Order.reflect_on_association(:order_items)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Order do
    it ' order should have one order shipping' do
      t = Order.reflect_on_association(:order_shipping)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Order do
    it 'order should have one  tote' do
      t = Order.reflect_on_association(:tote)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Order do
    it 'order should have one  order exception' do
      t = Order.reflect_on_association(:order_exception)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Order do
    it 'order should have many  order activities' do
      t = Order.reflect_on_association(:order_activities)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Order do
    it 'order should have many  order serials' do
      t = Order.reflect_on_association(:order_serials)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Order do
    it 'order should have many  order tags' do
      t = Order.reflect_on_association(:order_tags)
      expect(t.macro).to eq(:has_and_belongs_to_many)
    end
  end

  describe Order do
    it 'should belongs to packing user' do
      t = Order.reflect_on_association(:packing_user)
      expect(t.macro).to eq(:belongs_to)
    end
  end

  it 'should add GPSCANNED tag in Shipstation' do
    allow_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:get_tags_list).and_return({ 'gpscanned' => 123 })
    expect_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:add_gp_scanned_tag)

    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'inventory_warehouse')
    store = FactoryBot.create(:store, store_type: 'Shipstation API 2', name: 'Shipstation API 2', inventory_warehouse: inv_wh, status: true)
    FactoryBot.create(:shipstation_rest_credential, store: store, add_gpscanned_tag: true)
    order = FactoryBot.create(:order, status: 'awaiting', store_order_id: 512412, store: store)
    order.update(status: 'scanned')
  end
end
