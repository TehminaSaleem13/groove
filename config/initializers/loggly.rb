require 'logglier'

loggly_token = ENV['LOGGLY_TOKEN'] || 'no-token-available'
Rails.application.config.loggly_logger = Logglier.new("https://logs-01.loggly.com/inputs/#{loggly_token}/tag/groovepacker-backend/", threaded: true, format: :json)
