# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::ShipstationRuby::Rest::Service do
  let(:api_key) { 'your_api_key' }
  let(:api_secret) { 'your_api_secret' }
  let(:service) { described_class.new(api_key, api_secret) }

  before do
    stub_const('Groovepacker::ShipstationRuby::Rest::Service::DEFAULT_TRIAL_COUNT', 2)
  end

  describe '#initialize' do
    it 'initializes with api_key and api_secret' do
      expect(service.auth[:api_key]).to eq(api_key)
      expect(service.auth[:api_secret]).to eq(api_secret)
      expect(service.endpoint).to eq('https://ssapi.shipstation.com')
    end

    it 'raises ArgumentError if api_key or api_secret is nil' do
      expect { described_class.new(nil, api_secret) }.to raise_error(ArgumentError)
      expect { described_class.new(api_key, nil) }.to raise_error(ArgumentError)
    end
  end

  describe '#query' do
    context 'when response is successful' do
      it 'returns the response if type is create_label' do
        allow(HTTParty).to receive(:get).and_return(double(code: 200))
        response = service.query('/test', nil, 'get', 'create_label')
        expect(response.code).to eq(200)
      end

      it 'breaks the loop and returns the response' do
        allow(HTTParty).to receive(:get).and_return(double(code: 200))
        response = service.query('/test', nil, 'get')
        expect(response.code).to eq(200)
      end
    end

    context 'when encountering exceptions' do
      it 'handles exceptions and retries' do
        allow(HTTParty).to receive(:get).and_raise(Exception)
        expect { service.query('/test', nil, 'get') }.to raise_error(Exception)
      end

      it 'raises an error if maximum retries exceeded' do
        allow(HTTParty).to receive(:get).and_raise(Exception)
        expect { service.query('/test', nil, 'get') }.to raise_error(Exception)
      end
    end

    context 'when encountering error status codes' do
      it 'handles 401 unauthorized error' do
        allow(HTTParty).to receive(:put).and_return(double(code: 401))
        expect { service.query('/test', nil, 'put') }.to raise_error(Exception)
      end

      it 'handles 500 internal server error' do
        allow(HTTParty).to receive(:post).and_return(double(code: 500))
        expect { service.query('/test', nil, 'post') }.to raise_error(Exception)
      end

      it 'handles 504 gateway timeout error' do
        allow(HTTParty).to receive(:get).and_return(double(code: 504))
        expect { service.query('/test', nil, 'get') }.to raise_error(Exception)
      end
    end
  end
end
