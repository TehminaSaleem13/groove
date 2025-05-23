# frozen_string_literal: true

source 'http://rubygems.org'

ruby '3.1.5'

gem 'rails', '~> 6.1'

gem 'mysql2'
gem 'redis'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'angular-ui-bootstrap-rails'
  gem 'angularjs-rails', '>= 1.2.18'
  gem 'fingerprintjs-rails'
  gem 'jquery-fileupload-rails'
  gem 'jquery-ui-rails'
  gem 'momentjs-rails'
  gem 'sass-rails', '~> 6.0'
  gem 'uglifier', '>= 1.0.3'
end

group :development do
  gem 'better_errors', '>= 0.2.0'
  gem 'binding_of_caller', '>= 0.6.8'
  gem 'webrick', '~> 1.3'
end

group :development, :test do
  gem 'byebug'
  gem 'factory_bot_rails'
  gem 'parallel_tests', '~> 2.29.1'
  gem 'protractor-rails'
  gem 'pry'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rspec-rails', '~> 6.1'
  gem 'rspec_junit_formatter', '~> 0.4.0.pre2'
  gem 'rubocop-rspec', require: false
  gem 'rubycritic', require: false
  gem 'vcr'
  gem 'webmock'
end

group :test do
  gem 'codeclimate-test-reporter', require: false
  gem 'database_cleaner', '>= 0.9.1'
  gem 'mock_redis'
end

gem 'active_model_serializers'
gem 'sprockets-rails'
gem 'activerecord-import', '~> 1.7'
gem 'nokogiri', '~> 1.6'
gem 'ahoy_matey', '~> 2.2.0'
gem 'ros-apartment', require: 'apartment'
gem 'appsignal'
gem 'aws-sdk-s3', '~> 1'
gem 'aws_cf_signer'
gem 'barby'
gem 'bullet'
gem 'carrierwave_direct'
gem 'chunky_png'
gem 'clamp'
gem 'client_side_validations'
gem 'client_side_validations-simple_form', '~> 15.0'
gem 'country_select'
gem 'daemons'
gem 'delayed_job_active_record', '~> 4.1'
gem 'delayed_job_web'
gem 'devise'
gem 'doorkeeper', '~> 5.7'
gem 'dotenv-rails'
gem 'ebay', '1.1', git: 'https://github.com/kcpatel006/ebay4r.git'
gem 'excon'
gem 'figaro', '>= 0.5.0'
gem 'fog', '~> 1.42'
gem 'gelf'
gem 'intercom-rails'
gem 'jquery-rails'
gem 'letter_opener_web'
gem 'listen'
gem 'logglier'
gem 'lograge'
gem 'multi_xml'
gem 'mws-connect', '~> 0.0.8', git: 'https://github.com/kcpatel006/mws.git'
gem 'ng-rails-csrf'
gem 'oauth'
gem 'open4'
gem 'pdf-reader'
gem 'pdftk'
gem 'pry-rails'
gem 'rack-cors', require: 'rack/cors'
gem 'redis-session-store'
gem 'rollbar'
gem 'rubber'
gem 'ruby-mws', git: 'https://github.com/kcpatel006/ruby-mws.git'
gem 'ruby_odata'
gem 'rubyzip'
gem 's3'
gem 'savon', '~> 2.13'
gem 'shipping_easy', '>= 0.7.1'
gem 'shopify_api', '> 12.2'
gem 'simple_form', '>= 4.0.0'
gem 'soap2r', git: 'https://github.com/navaratan-tech/soap4r.git'

# Payments
gem 'stripe', '>= 1.57.1'

# This obscure dependency is locked here because of our older Ubuntu servers. If you get a modern operating system, (post 2019) then you can remove this
gem 'unf_ext'
gem 'wannabe_bool'

# Cron Jobs
gem 'whenever', require: false

# PDF Generation
gem 'wicked_pdf', '>= 0.11'
gem 'wkhtmltopdf-binary'

# FTP/SFTP
gem 'net-ftp', '~> 0.3'
gem 'net-sftp', '~> 4.0'
gem 'net-ssh', '~> 7.2'

# Parser Gem for Scout APM
gem 'parser', '~> 3.3'

# Rack middleware for blocking & throttling abusive requests
gem 'rack-attack', '~> 6.7'

# Monitoring
gem 'scout_apm'
gem "scout_apm_logging", "~> 1.1"
