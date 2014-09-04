Groovepacks::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true

  #Default URL options for mailers
  # config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  # # config.action_mailer.delivery_method = :smtp
  # # config.action_mailer.smtp_settings = {
  # #   :address => "mail.groovepacker.com",
  # #   :authentication=> "plain",
  # #   :enable_starttls_auto => false,
  # #   :user_name => 'app@groovepacker.com',
  # #   :password => '1packermail!'
  # # }
  config.action_mailer.delivery_method = :smtp
  # config.action_mailer.smtp_settings = {
  #   :address => "mail.groovepacker.com",
  #   :authentication=> "plain",
  #   :enable_starttls_auto => false,
  #   :user_name => 'app@groovepacker.com',
  #   :password => '1packermail!',
  #   :openssl_verify_mode  => 'none'
  # }

  # config.action_mailer.smtp_settings = {
  #   :address => "smtp.gmail.com",
  #   :port => 587,  
  #   :authentication => 'plain',
  #   :enable_starttls_auto => true,
  #   :domain => 'gmail.com',
  #   :user_name => 'groovepacker@gmail.com',
  #   :password => '1TempPass!',
  #   :openssl_verify_mode  => 'none',
  #   :TLS_required => 'yes'
  # }
  # config.action_mailer.smtp_settings = {
  #   :address => "smtp.gmail.com",
  #   :port => 587,  
  #   :authentication => "plain",
  #   :enable_starttls_auto => true,
  #   :domain => 'gmail.com',
  #   :user_name => 'uvarsity.elearn@gmail.com',
  #   :password => 'uvarsity2015',
  #   :openssl_verify_mode  => 'none'
  # }
  config.action_mailer.smtp_settings = {
    :address => "smtp.mandrillapp.com",
    :port => 587,  
    :authentication => "plain",
    :enable_starttls_auto => true,
    :domain => 'groovepacker.com',
    :user_name => 'groovepacker@gmail.com',
    :password => 'ckWnOifHhLOJRiqZQ-ZRKA',
    :openssl_verify_mode  => 'none'
  }

  Rails.logger = Logger.new(STDOUT)
  config.log_level = :warn
  
  ENV['AMAZON_MWS_ACCESS_KEY_ID'] = "AKIAJ4VZ2GY7HZUL277Q"
  ENV['AMAZON_MWS_SECRET_ACCESS_KEY'] = "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"


  ENV['EBAY_APP_ID'] = "Navarata-c04e-41cb-a923-77755ae59a0f"
  ENV['EBAY_CERT_ID'] = "596cd688-b754-49b1-8b92-a3c393caed49"
  ENV['EBAY_DEV_ID'] = "568a739c-a13d-40e5-922a-6e3ecc652d9d"
  ENV['EBAY_RU_NAME'] = "Navaratan_Techn-Navarata-c04e-4-kglxwbl"
  ENV['EBAY_SANDBOX_MODE'] = "NO"
  # ENV['EBAY_APP_ID'] = "Navarata-607d-4a45-8a42-51c735a57026"
  # ENV['EBAY_CERT_ID'] = "86380834-e449-4dd9-b19f-748b4625533d"
  # ENV['EBAY_DEV_ID'] = "568a739c-a13d-40e5-922a-6e3ecc652d9d"
  # ENV['EBAY_RU_NAME'] = "Navaratan_Techn-Navarata-607d-4-klyznn"
  # ENV['EBAY_SANDBOX_MODE'] = "YES"

  ENV['SHIPSTATION_USERNAME'] = "dreadhead"
  ENV['SHIPSTATION_PASSWORD'] = "g8J$v5KLoP"

  # Stripe test keys
  ENV['STRIPE_API_KEY'] = "sk_test_4QS2OJ8BkMWcuzCWrHrKGlz9"
  ENV['STRIPE_PUBLIC_KEY'] = "pk_test_4QS2UN3famIPlHtp2Q7ykpDf"
end
