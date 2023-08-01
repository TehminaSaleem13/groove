require 'rails_helper'

RSpec.describe OrderClassMethodsHelper, type: :controller do
  describe '#emit_notification_for_range_import' do
    let(:user) { create(:user) }
    let(:inventory_warehouse) { create(:inventory_warehouse, is_default: true) }
    let(:store) { create(:store, status: true, store_type: 'Shopify', inventory_warehouse: inventory_warehouse) }
    let(:initial_date) { DateTime.new(2023, 7, 10).in_time_zone.to_date }
    let(:lro_date) { DateTime.new(2023, 7, 20).in_time_zone.to_date }

    it 'emits the notification with the correct data' do
      Order.emit_notification_for_range_import(user.id, store, initial_date, lro_date)
    end
  end
end