# frozen_string_literal: true

Rack::Attack.enabled = ENV['ENABLE_RACK_ATTACK'] || Rails.env.production?

redis_url = "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"
redis_url += "?password=#{ENV['REDIS_PASSWORD']}" if ENV['REDIS_PASSWORD'].present?
ENV['REDIS_URL'] = redis_url

# Fallback to memory if we don't have Redis present or we're in test mode
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if !ENV['REDIS_URL'] || Rails.env.test?

# Allow 5 request per minute for Shipstation Webhooks
Rack::Attack.throttle('shipstation webhooks', limit: 5, period: 1.minute) do |req|
  req.ip if req.path.include?('/webhooks/shipstation/')
end
