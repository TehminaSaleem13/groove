# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailScheduling do
  describe '#should_send_email' do
    let(:model) { [GeneralSetting, InventoryReportsSetting].sample }
    let(:model_object) { model.new }
    let(:monday_date) { Date.new(2023, 5, 22) } # A Monday
    let(:tuesday_date) { Date.new(2023, 5, 23) } # A Tuesday

    context 'when send_email_on_* is true for the corresponding weekday' do
      before do
        allow(model_object).to receive(:send_email_on_mon).and_return(true)
        allow(model_object).to receive(:send_email_on_tue).and_return(true)
      end

      it 'returns true for Monday when send_email_on_mon is true' do
        expect(model_object.should_send_email(monday_date)).to be true
      end

      it 'returns true for Tuesday when send_email_on_tue is true' do
        expect(model_object.should_send_email(tuesday_date)).to be true
      end
    end

    context 'when send_email_on_* is false for the corresponding weekday' do
      before do
        allow(model_object).to receive(:send_email_on_mon).and_return(false)
        allow(model_object).to receive(:send_email_on_tue).and_return(false)
      end

      it 'returns false for Monday when send_email_on_mon is false' do
        expect(model_object.should_send_email(monday_date)).to be false
      end

      it 'returns false for Tuesday when send_email_on_tue is false' do
        expect(model_object.should_send_email(tuesday_date)).to be false
      end
    end
  end
end
