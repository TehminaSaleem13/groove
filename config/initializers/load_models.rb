# frozen_string_literal: true

Dir["#{Rails.root}/app/models/**/*.rb"].each { |file| require_dependency file } if Rails.env == 'development'

WEBrick::HTTPRequest.const_set('MAX_URI_LENGTH', 10_240) if defined?(WEBrick::HTTPRequest)
