# frozen_string_literal: true

require 'rails_helper'

describe ElixirApi::Processor::CSV::Base do
  let(:tenant) { Apartment::Tenant.current }

  describe '#host_url' do
    let(:import_site_host) { 'testpacker.com' }
    let(:expected_result) { "https://#{tenant}.#{import_site_host}" }
    let(:result) { subject.host_url(tenant) }

    before do
      stub_const('ENV', 'IMPORT_SITE_HOST' => import_site_host)
    end

    it 'returns host_url' do
      expect(result).to eq(expected_result)
    end
  end
end
