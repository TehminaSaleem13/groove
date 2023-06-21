require 'rails_helper'

RSpec.describe Groovepacker::LogglyLogger do
  describe '.log_request' do
    let(:request) { instance_double(ActionDispatch::Request, method: 'POST', original_url: 'http://example.com', params: { key: 'value' }, env: { 'HTTP_USER_AGENT' => 'Test User Agent' }) }
    let(:request_body) { 'Test request body' }
    let(:log_type) { 'test_log' }
    let(:tenant) { 'test_tenant' }
    let(:loggly_logger) { instance_double(Logger) }
    let(:payload) do
      {
        rails_env: Rails.env,
        log_type: "#{tenant}-#{log_type}",
        tenant: tenant,
        method: request.method,
        url: request.original_url,
        params: request.params,
        headers: { 'HTTP_USER_AGENT' => 'Test User Agent' },
        body: request_body
      }.to_json
    end

    before do
      allow(Rails.application.config).to receive(:loggly_logger).and_return(loggly_logger)
      allow(loggly_logger).to receive(:info)
      allow(ENV).to receive(:[]).with('LOGGLY_TOKEN').and_return('test_token')
    end

    it 'sends the log payload to loggly_logger' do
      expect(loggly_logger).to receive(:info).with(payload)

      Groovepacker::LogglyLogger.log_request(request, request_body, log_type, tenant)
    end

    it 'rescues and logs any errors that occur' do
      allow(loggly_logger).to receive(:info).and_raise(StandardError, 'Loggly Error')

      expect(Rails.logger).to receive(:info).exactly(3).times
      expect { Groovepacker::LogglyLogger.log_request(request, request_body, log_type, tenant) }.not_to raise_error
    end
  end

  describe '.log' do
    let(:logs) { 'Test request body' }
    let(:log_type) { 'test_log' }
    let(:tenant) { 'test_tenant' }
    let(:loggly_logger) { instance_double(Logger) }
    let(:payload) do
      {
        rails_env: Rails.env,
        log_type: "#{tenant}-#{log_type}",
        tenant: tenant,
        logs: logs
      }.to_json
    end

    before do
      allow(Rails.application.config).to receive(:loggly_logger).and_return(loggly_logger)
      allow(loggly_logger).to receive(:info)
      allow(ENV).to receive(:[]).with('LOGGLY_TOKEN').and_return('test_token')
    end

    it 'sends the log payload to loggly_logger' do
      expect(loggly_logger).to receive(:info).with(payload)

      Groovepacker::LogglyLogger.log(tenant, log_type, logs)
    end

    it 'rescues and logs any errors that occur' do
      allow(loggly_logger).to receive(:info).and_raise(StandardError, 'Loggly Error')

      expect(Rails.logger).to receive(:info).exactly(3).times
      expect { Groovepacker::LogglyLogger.log(tenant, log_type, logs) }.not_to raise_error
    end
  end

end
