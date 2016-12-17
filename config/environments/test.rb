Groovepacks::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_assets = true
  config.static_cache_control = "public, max-age=3600"

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  # config.action_mailer.delivery_method = :test
  config.action_mailer.delivery_method = :smtp

  $redis = Redis.new(host: ENV['REDIS_HOST'], port: ENV['REDIS_PORT'].to_i,
    password: ENV['REDIS_PASSWORD'], driver: :hiredis)

  config.cache_store = :redis_store, $redis.as_json['options'].merge(db: 15) # :memory_store, { size: 64.megabytes } #

  config.action_mailer.smtp_settings = {
    :address => "email-smtp.us-east-1.amazonaws.com",
    :port => 587,
    :authentication => "login",
    :enable_starttls_auto => true,
    :domain => 'groovepacker.com',
    :user_name => 'AKIAIB6EZSOUF5ZOMOKQ',
    :password => 'ArzLSfZxyQtXjTSnd3ZAxwbqIGBOZky/u4YD+A479ghZ',
    :openssl_verify_mode  => 'none'
  }
  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  ENV['SHOPIFY_BILLING_IN_TEST'] = "true"
end
