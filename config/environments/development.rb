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
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
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
    :address => "email-smtp.us-east-1.amazonaws.com",
    :port => 587,
    :authentication => "login",
    :enable_starttls_auto => true,
    :domain => 'groovepacker.com',
    :user_name => 'AKIAIB6EZSOUF5ZOMOKQ',
    :password => 'ArzLSfZxyQtXjTSnd3ZAxwbqIGBOZky/u4YD+A479ghZ',
    :openssl_verify_mode  => 'none'
  }

  Rails.logger = Logger.new(STDOUT)
  config.log_level = :info

  $redis = Redis.new(:host => ENV['REDIS_HOST'], :port=> ENV['REDIS_PORT'].to_i,
    :password => ENV['REDIS_PASSWORD'])

  config.cache_store = :redis_store, $redis.as_json['options'].merge(db: 15) # :memory_store, { size: 64.megabytes } #

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

  ENV['SHOPIFY_API_KEY'] = "1177da0ae0ee723ad479792561c4c480"
  ENV['SHOPIFY_SHARED_SECRET'] = "8f48a567ba58e3ac057253cdde377fc2"
  ENV["SHOPIFY_REDIRECT_HOST"] = "localpacker.com"
  ENV['SHOPIFY_ONE_TIME_PAYMENT'] = '0'

  ENV['BC_CALLBACK_HOST'] = "admin.barcodepacker.com"
  ENV['BC_CLIENT_ID'] = "hcd39v5m3dapbtpa2gpi5f4iz3syjps"
  ENV['BC_CLIENT_SECRET'] = "d8b8es9ojf0x2dyi1jx12ozvbatcqhr"
  ENV['BC_APP_URL'] = "https://store-1pslcuh.mybigcommerce.com/manage/marketplace/apps/4907"

  # Stripe test keys
  ENV['STRIPE_API_KEY'] = "sk_test_4QS2OJ8BkMWcuzCWrHrKGlz9"
  ENV['STRIPE_PUBLIC_KEY'] = "pk_test_4QS2UN3famIPlHtp2Q7ykpDf"

  ENV['HOST_NAME'] = 'localpacker.com'

  ENV['ONE_TIME_PAYMENT'] = '50000'
  ENV['BC_ONE_TIME_PAYMENT'] = '0'

  #S3 access details
  ENV['S3_ACCESS_KEY_ID'] = 'AKIAIBDKVKEM7HNZUQAA'
  ENV['S3_ACCESS_KEY_SECRET'] = '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'
  ENV['S3_BUCKET_NAME'] = 'groove-dev'
  ENV['S3_BUCKET_REGION'] = 'us-east-1'
  ENV['S3_BASE_URL'] = 'https://s3.amazonaws.com/groove-dev'

  #Feature Variables
  ENV['DASHBOARD_ENABLE'] = 'YES'

  ENV["SITE_HOST"] = "localpacker.com"

  # analytic server
  ENV["GROOV_ANALYTIC"] = "localhost:4000"

  ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"] = ""
  ENV["PRODUCTS_IMPORT_EMAILS"] = ""
  ENV["PRODUCTS_IMPORT_COMPLETE_EMAILS"] = ""

  #Campaign-Monitoring API_KEY and CLIENT_ID
  ENV['CAMPAIGN_MONITOR_API_KEY'] = "0319589f90c1b2f6a1034c2d8cd47604"
  ENV['CAMPAIGN_MONITOR_CLIENT_ID'] = "1c1a38f864c174b42eb2ebcd613b6969"
  #List Name - Dev All Leads
  ENV['CAMPAIGN_MONITOR_LEADS_LIST_ID'] = "f56496637a0ba321d130137d61145305"
  #List Name - Dev New Customers
  ENV['CAMPAIGN_MONITOR_NEW_CUSTOMER_LIST_ID'] = "78a4f2ed6ed69cc395f886950cf761bc"
  #List Name - Dev All Customers
  ENV['CAMPAIGN_MONITOR_ALL_CUSTOMERS_LIST_ID'] = "98cf23f2620ae5062d9657ed991e3466"
end
