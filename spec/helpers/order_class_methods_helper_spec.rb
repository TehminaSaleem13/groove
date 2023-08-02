# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderClassMethodsHelper, type: :controller do
  describe '#emit_notification_for_default_import_date' do
    let(:user_id) { 1 }
    let(:store) { instance_double('Store', id: 1, name: "Test SS", store_type: 'Shipstation API 2') }
    let(:last_import_days) { nil }
    let(:current_import_days) { 1 }

    it 'emits the notification' do
      allow(GroovRealtime).to receive(:emit)
      Order.emit_notification_for_default_import_date(user_id, store, last_import_days, current_import_days)

      expect(GroovRealtime).to have_received(:emit)
    end
  end
end
