# frozen_string_literal: true

require 'rails_helper'

describe ElixirApi::Processor::CSV::OrdersToXML do
  let(:order_params) { { 'params' => {} } }
  let(:instance) { described_class.new(order_params) }

  before do
    create(:general_setting)
    allow(ENV).to receive(:[]).with('DB_USERNAME').and_return('test_user')
    allow(ENV).to receive(:[]).with('DB_PASSWORD').and_return('test_password')
    allow(ENV).to receive(:[]).with('DB_HOST').and_return('localhost')
    allow(ENV).to receive(:[]).with('DB_PORT').and_return('3306')
  end

  describe '#set_db_config' do
    before do
      allow(instance).to receive(:tenant_offset).and_return('+0000')
    end

    it 'returns a hash with database configuration' do
      expected_config = {
        'db_user' => 'test_user',
        'db_password' => 'test_password',
        'db_host' => 'localhost',
        'db_port' => '3306',
        'tenant_offset' => '+0000'
      }

      expect(instance.send(:set_db_config)).to eq(expected_config)
    end
  end

  describe '#tenant_offset' do
    before do
      allow(GeneralSetting).to receive_message_chain(:first, :new_time_zone).and_return('America/New_York')
    end

    it 'returns the correct time zone offset' do
      expected_offset = ActiveSupport::TimeZone.new('America/New_York').now.formatted_offset(false)
      expect(instance.send(:tenant_offset)).to eq(expected_offset)
    end
  end
end
