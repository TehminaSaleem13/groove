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

  $redis = Redis.new(:host => 'localhost', :port=> 6379)

  config.action_mailer.smtp_settings = {
    :address => "smtp.gmail.com",
    :port => 587,  
    :authentication => "plain",
    :enable_starttls_auto => true,
    :user_name => 'liquorexam@gmail.com',
    :password => 'alaskatap',
    :openssl_verify_mode  => 'none'
  }
  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr
  ENV['AMAZON_MWS_ACCESS_KEY_ID'] = "AKIAJRXZUVPLLINJ2EUQ"
  ENV['AMAZON_MWS_SECRET_ACCESS_KEY'] = "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"

  ENV['STRIPE_API_KEY'] = "sk_test_4QS2OJ8BkMWcuzCWrHrKGlz9"
  ENV['STRIPE_PUBLIC_KEY'] = "pk_test_4QS2UN3famIPlHtp2Q7ykpDf"
  ENV['HOST_NAME'] = 'testpacker.com'
  ENV['ONE_TIME_PAYMENT'] = '50000'
end
