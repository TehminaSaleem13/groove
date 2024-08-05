# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StoreConcern, type: :concern do
  let(:dummy_instance) do
    Class.new do
      include StoreConcern

      def initialize(store)
        @store = store
      end
    end.new(store)
  end
  
  let(:redis) { double('Redis') }
  let(:current_tenant) { 'some_tenant' }
  let(:store) { double('Store', id: 1) }
  let(:s3_base_url) { 'some_s3_base_url' }
  let(:kind) { 'some_kind' }
  let(:csv_data_utf8) { "ORDER,QTY,DESCRIPTION,PART NUMBER\n35643AXB,1,\"TEK SCREW, 10-16 x 3/4\", Unslot HWH (Self-Drilling), Grade __ (Zinc)\",10T75TUX0Z (QTY-200)" }
  let(:csv_data_iso) { "ORDER,QTY,DESCRIPTION,PART NUMBER\n35643AXB,1,\"TEK SCREW, 10-16 x 3/4\", Unslot HWH (Self-Drilling), Grade __ (Zinc)\",10T75TUX0Z (QTY-200)".encode('ISO-8859-1') }
  let(:csv_data_default) { "ORDER,QTY,DESCRIPTION,PART NUMBER\r\n35643AXB,1,\"TEK SCREW, 10-16 x 3/4\",10T75TUX0Z (QTY-200)" }

  before do
    allow(Apartment::Tenant).to receive(:current).and_return(current_tenant)
    allow($redis).to receive(:get).and_return(nil)
    ENV['S3_BASE_URL'] = s3_base_url
  end

  describe '#csv_data' do
    context 'when data is UTF-8 encoded' do
      before do
        allow($redis).to receive(:get).with("#{s3_base_url}/#{current_tenant}/csv/#{kind}.#{store.id}.csv").and_return(csv_data_utf8)
      end

      it 'returns the correctly formatted data' do
        result = dummy_instance.csv_data(kind)
        expect(result).to eq(csv_data_utf8.gsub("\"\"", ""))
      end
    end

    context 'when data is ISO-8859-1 encoded' do
      before do
        allow($redis).to receive(:get).with("#{s3_base_url}/#{current_tenant}/csv/#{kind}.#{store.id}.csv").and_return(csv_data_iso)
      end

      it 'returns the correctly formatted data' do
        result = dummy_instance.csv_data(kind)
        expect(result).to eq(csv_data_utf8.gsub("\"\"", ""))
      end
    end

    context 'when an error occurs' do
      before do
        allow($redis).to receive(:get).with("#{s3_base_url}/#{current_tenant}/csv/#{kind}.#{store.id}.csv").and_raise(StandardError)
        allow($redis).to receive(:get).with("#{s3_base_url}/#{current_tenant}/csv/#{kind}.#{store.id}.csv").and_return(csv_data_default)
      end

      it 'handles the error and returns formatted data' do
        result = dummy_instance.csv_data(kind)
        expect(result).to eq(csv_data_default.gsub("\r\n", "\n").tr("\r", "\n").gsub("\"\"", ""))
      end
    end
  end
end
