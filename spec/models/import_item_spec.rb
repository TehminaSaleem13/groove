# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportItem, type: :model do
  it 'import item should belongs to order import summary' do
    import_item = described_class.reflect_on_association(:order_import_summary)
    expect(import_item.macro).to eq(:belongs_to)
  end

  it 'import item should belongs to store' do
    import_item = described_class.reflect_on_association(:store)
    expect(import_item.macro).to eq(:belongs_to)
  end

  describe '#get_import_item_info' do
    let(:store) { create(:store, :veeqo) }
    let(:user) { create(:user, name: 'Test User') }
    let(:order_import_summary) { create(:order_import_summary, user: user, created_at: Time.zone.now) }
    let(:import_item) { create(:import_item, store_id: store.id, order_import_summary_id: order_import_summary.id) }
    let(:current_time) { Time.zone.now }

    before do
      allow(import_item).to receive(:to_import).and_return(5)
      allow(import_item).to receive(:success_imported).and_return(2)
      allow(import_item).to receive(:updated_orders_import).and_return(1)
      allow(import_item).to receive(:order_import_summary).and_return(order_import_summary)
      allow(import_item).to receive(:current_increment_id).and_return('1005')
      allow(import_item).to receive(:created_at).and_return(current_time - 1.hour)
      allow(import_item).to receive(:updated_at).and_return(current_time - 30.minutes)

      create(:order, id: 1, increment_id: '1001', store_id: store.id, status: 'awaiting')
      create(:order, id: 2, increment_id: '1002', store_id: store.id, status: 'awaiting')
      create(:order, id: 3, increment_id: '1003', store_id: store.id, status: 'awaiting')

      $redis.set("#{Apartment::Tenant.current}_#{store.id}", current_time.to_s)
    end

    it 'returns correct import item info' do
      result = import_item.get_import_item_info(store.id)

      expect(result[:status]).to be true
      expect(result[:total_imported]).to eq(3)
      expect(result[:remaining_items]).to eq(2)
      expect(result[:completed]).to eq('1002')
      expect(result[:processed_orders].count).to eq(3)
      expect(result[:run_by]).to eq('Test User')
      expect(result[:import_start]).to eq(order_import_summary.created_at)
      expect(result[:import_end]).to eq(import_item.updated_at)
      expect(result[:in_progess]).to eq('1005')
      expect(result[:elapsed_time]).not_to be_nil
      expect(result[:elapsed_time_remaining]).not_to be_nil
      expect(result[:store_id]).to eq(store.id)
    end

    it 'returns status false when there are no items to import' do
      allow(import_item).to receive(:to_import).and_return(0)
      result = import_item.get_import_item_info(store.id)
      expect(result[:status]).to be false
    end
  end
end
