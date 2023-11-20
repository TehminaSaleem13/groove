# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::Dashboard::Stats::AnalyticStatStream do
  let(:store) { create(:store, :csv) }
  let(:order_status) { 'scanned' }
  let(:order) { create(:order, increment_id: 'Test Order', status: order_status, store: store) }
	let(:result) do 
		{
			order_increment_id: '',
			item_count: 0,
			scanned_on: nil,
			packing_user_id: 0,
			packing_user_name: '',
			inaccurate_scan_count: 0,
			clicked_scanned_qty: 0,
			box_number: 0,
			packing_time: 0,
			scanned_item_count: 0,
			exception_description: nil,
			exception_reason: nil,
			exception_assoicated_user: 0
		}
	end

	describe '#bind_order_data' do
		it 'send order data for user stat report' do
			subject.bind_order_data(order, result)
			expect(result[:order_increment_id]).to eq('Test Order')
			expect(result[:packing_user_id]).to eq(420)
		end
	end
end  