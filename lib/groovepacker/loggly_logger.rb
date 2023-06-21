# frozen_string_literal: true

module Groovepacker
  class LogglyLogger
    def self.log_request(request, request_body, log_type, tenant = Apartment::Tenant.current)
      return unless ENV['LOGGLY_TOKEN']

      payload = request_payload(request, request_body, log_type, tenant)
      loggly_logger.info(payload)
    rescue StandardError => e
      Rails.logger.info('Loggly Error')
      Rails.logger.info(e)
      Rails.logger.info(e.message)
    end

    def self.log(tenant, log_type, logs)
      return unless ENV['LOGGLY_TOKEN']

      payload = {
        rails_env: Rails.env,
        log_type: "#{tenant}-#{log_type}",
        tenant: tenant,
        logs: logs
      }.to_json

      loggly_logger.info(payload)
    rescue StandardError => e
      Rails.logger.info('Loggly Error')
      Rails.logger.info(e)
      Rails.logger.info(e.message)
    end

    private_class_method def self.loggly_logger
      Rails.application.config.loggly_logger
    end

    private_class_method def self.request_payload(request, request_body, log_type, tenant)
      {
        rails_env: Rails.env,
        log_type: "#{tenant}-#{log_type}",
        tenant: tenant,
        method: request.method,
        url: request.original_url,
        params: request.params,
        headers: request.env.select { |key, _value| key.start_with?('HTTP') },
        body: request_body
      }.to_json
    end
  end
end
