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
  # config.action_mailer.smtp_settings = {
  #   :address => "mail.groovepacker.com",
  #   :authentication=> "plain",
  #   :enable_starttls_auto => false,
  #   :user_name => 'app@groovepacker.com',
  #   :password => '1packermail!',
  #   :openssl_verify_mode  => 'none'
  # }

  ENV['REDIS_HOST'] = 'groovelytics-redis'
  ENV['REDIS_PASSWORD'] = 'WmHE1h2oRJqIW76AtsC1Eg_ZJXe*UpOpJ1OT_yBKoFQYR1r938Oc!2Ahv2wr'
  ENV['REDIS_PORT'] = '7743'
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
  ENV['AMAZON_MWS_ACCESS_KEY_ID'] = "AKIAJ4VZ2GY7HZUL277Q"
  ENV['AMAZON_MWS_SECRET_ACCESS_KEY'] = "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"

  ENV['STRIPE_API_KEY'] = "sk_test_4QS2OJ8BkMWcuzCWrHrKGlz9"
  ENV['STRIPE_PUBLIC_KEY'] = "pk_test_4QS2UN3famIPlHtp2Q7ykpDf"
  ENV['HOST_NAME'] = 'testpacker.com'
  ENV['ONE_TIME_PAYMENT'] = '50000'
  ENV['BC_ONE_TIME_PAYMENT'] = '0'


  #S3 access details
  ENV['S3_ACCESS_KEY_ID'] = 'AKIAJ4RBSXRA6F7VW3ZA'
  ENV['S3_ACCESS_KEY_SECRET'] = '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'
  ENV['S3_BUCKET_NAME'] = 'groove-dev'
  ENV['S3_BASE_URL'] = 'https://s3-ap-southeast-1.amazonaws.com/groove-dev'

  #Shipstation rest API test api_key and api_secret
  ENV['SHIPSTATION_REST_API_KEY'] = "45893449eae24f2e8bc7992904016ca6"
  ENV['SHIPSTATION_REST_API_SECRET'] = "ddefa497b0fc48c0b162a533920ce990"

  ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"] = "svisamsetty@navaratan.com, groovepacker+importfail@gmail.com, kcpatel006@gmail.com, jarett@dcssquared.com"
  ENV["PRODUCTS_IMPORT_EMAILS"] = "svisamsetty@navaratan.com, kcpatel006@gmail.com, groovepacker@gmail.com"
  ENV["PRODUCTS_IMPORT_COMPLETE_EMAILS"] = "kcpatel006@gmail.com"
end
