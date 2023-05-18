# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailScheduling do
  describe '#should_send_email' do
    let(:model) { [GeneralSetting, InventoryReportsSetting].sample }
    let(:model_object) { model.new }
    let(:monday_date) { Date.new(2023, 5, 22) } # A Monday
    let(:tuesday_date) { Date.new(2023, 5, 23) } # A Tuesday
    let(:wednesday_date) { Time.new(2023, 1, 4) } # A Wednesday
    let(:thursday_date) { Time.new(2023, 1, 5) } # A Thursday
    let(:friday_date) { Time.new(2023, 1, 6) } # A Friday
    let(:saturday_date) { Time.new(2023, 1, 7) } # A Saturday
    let(:sunday_date) { Time.new(2023, 1, 8) } # A Sunday

    context 'when send_email_on_* is true for the corresponding weekday' do
      before do
        allow(model_object).to receive(:send_email_on_mon).and_return(true)
        allow(model_object).to receive(:send_email_on_tue).and_return(true)
        allow(model_object).to receive(:send_email_on_wed).and_return(true)
        allow(model_object).to receive(:send_email_on_thurs).and_return(true)
        allow(model_object).to receive(:send_email_on_fri).and_return(true)
        allow(model_object).to receive(:send_email_on_sat).and_return(true)
        allow(model_object).to receive(:send_email_on_sun).and_return(true)
      end

      it 'returns true for Monday when send_email_on_mon is true' do
        expect(model_object.should_send_email(monday_date)).to be true
      end

      it 'returns true for Tuesday when send_email_on_tue is true' do
        expect(model_object.should_send_email(tuesday_date)).to be true
      end

      it 'returns true for Wednesday when send_email_on_wed is true' do
        expect(model_object.should_send_email(wednesday_date)).to be true
      end

      it 'returns true for Thursday when send_email_on_thurs is true' do
        expect(model_object.should_send_email(thursday_date)).to be true
      end

      it 'returns true for Friday when send_email_on_fri is true' do
        expect(model_object.should_send_email(friday_date)).to be true
      end

      it 'returns true for Saturday when send_email_on_sat is true' do
        expect(model_object.should_send_email(saturday_date)).to be true
      end

      it 'returns true for Sunday when send_email_on_sun is true' do
        expect(model_object.should_send_email(sunday_date)).to be true
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
