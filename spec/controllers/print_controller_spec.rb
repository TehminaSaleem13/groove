# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintController, type: :controller do
  describe '#qz_certificate' do
    let(:certificate_content) { 'certificate content' }

    before do
      allow(File).to receive(:read)
        .with(Rails.root.join('config', 'qz_license', 'digital-certificate.txt'))
        .and_return(certificate_content)

      allow(File).to receive(:exist?)
        .and_return(true)
    end

    it 'renders the digital certificate' do
      get :qz_certificate
      expect(response.body).to eq(certificate_content)
    end

    it 'returns :service_unavailable when an error occurs' do
      allow(File).to receive(:read)
        .and_raise(StandardError)

      get :qz_certificate
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe '#qz_sign' do
    let(:request_params) { 'some data' }
    let(:encoded_data) { 'encoded data' }
    let(:mocked_key) { instance_double(OpenSSL::PKey::PKey, sign: 'signed data') }

    before do
      allow(OpenSSL::PKey).to receive(:read)
        .and_return(mocked_key)

      allow(Base64).to receive(:encode64)
        .with('signed data')
        .and_return(encoded_data)
    end

    it 'renders the signed and encoded data' do
      allow(File).to receive(:exist?)
        .and_return(true)

      post :qz_sign, params: { request: request_params }
      expect(response.body).to eq(encoded_data)
    end

    it 'returns :service_unavailable when an error occurs' do
      allow(OpenSSL::PKey).to receive(:read)
        .and_raise(StandardError)

      post :qz_sign
      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
