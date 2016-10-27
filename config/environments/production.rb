Groovepacks::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = true

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  config.action_mailer.delivery_method = :smtp

  # config.action_mailer.smtp_settings = {
  #   :address => "smtp.gmail.com",
  #   :port => 587,
  #   :authentication => "plain",
  #   :enable_starttls_auto => true,
  #   :domain => 'gmail.com',
  #   :user_name => 'groovepacker@gmail.com',
  #   :password => '1TempPass!',
  #   :openssl_verify_mode  => 'none'
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

  # ENV['REDIS_HOST'] = 'groovelytics-redis'
  # ENV['REDIS_PASSWORD'] = '6t!@D2gA4i8njgz^qut#owyaiJXYfM5q'
  # ENV['REDIS_PORT'] = '7743'
  $redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'].to_i,
    password: ENV['REDIS_PASSWORD'])

  config.cache_store = :redis_store, $redis.as_json['options'].merge(db: 15) # :memory_store, { size: 64.megabytes } #
  
  # $redis = Redis.new(:host => 'groove-prod-1', :port=> 6379)
  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  ENV['AMAZON_MWS_ACCESS_KEY_ID'] = "AKIAJ4VZ2GY7HZUL277Q"
  ENV['AMAZON_MWS_SECRET_ACCESS_KEY'] = "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"

  ENV['EBAY_APP_ID'] = "DSO698331-163d-4ffd-be1a-0eceb5ae5be"
  ENV['EBAY_CERT_ID'] = "a5b0c5cb-7863-4ade-92f0-1331997def8c"
  ENV['EBAY_DEV_ID'] = "353bd404-651b-4431-955d-25e0a0c8140f"
  ENV['EBAY_RU_NAME'] = "DSO-DSO698331-163d--aptkv"
  ENV['EBAY_SANDBOX_MODE'] = "NO"

  ENV['SHIPSTATION_USERNAME'] = "dreadhead"
  ENV['SHIPSTATION_PASSWORD'] = "g8J$v5KLoP"

  ENV['SHOPIFY_API_KEY'] = "368d134ea37fffb3dbe4d67c22dbd733"
  ENV['SHOPIFY_SHARED_SECRET'] = "23f69cf421abb3af107934410ba7c624"
  ENV["SHOPIFY_REDIRECT_HOST"] = "groovepacker.com"
  ENV['SHOPIFY_ONE_TIME_PAYMENT'] = '0'

  ENV['ROLLBAR_ACCESS_TOKEN'] = "6fd94c05f4bd41cd8a788bd71752b80b"

  ENV['BC_CALLBACK_HOST'] = "admin.groovepacker.com"
  ENV['BC_CLIENT_ID'] = "hcd39v5m3dapbtpa2gpi5f4iz3syjps"
  ENV['BC_CLIENT_SECRET'] = "d8b8es9ojf0x2dyi1jx12ozvbatcqhr"
  ENV['BC_APP_URL'] = "https://store-1pslcuh.mybigcommerce.com/manage/marketplace/apps/5386"

  # Stripe production keys
  ENV['STRIPE_API_KEY'] = "sk_live_4QS2d8WaWqbIqBBvCuXgbzPf"
  ENV['STRIPE_PUBLIC_KEY'] = "pk_live_4QS2iJSARAa7PmM1IG70xnJ9"
  ENV['HOST_NAME'] = 'groovepacker.com'
  ENV['ONE_TIME_PAYMENT'] = '50000'
  ENV['BC_ONE_TIME_PAYMENT'] = '0'

  ENV['S3_ACCESS_KEY_ID'] = 'AKIAIBDKVKEM7HNZUQAA'
  ENV['S3_ACCESS_KEY_SECRET'] = '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'
  ENV['S3_BUCKET_NAME'] = 'groove-prod'
  ENV['S3_BUCKET_REGION'] = 'us-west-2'
  ENV['S3_BASE_URL'] = 'https://s3-us-west-2.amazonaws.com/groove-prod'

  #Feature Variables
  ENV['DASHBOARD_ENABLE'] = 'NO'

  ENV["SITE_HOST"] = "groovepacker.com"

  # analytic server
  # ENV["GROOV_ANALYTIC"] = "orderpacker.com"
  # ENV["GROOV_ANALYTIC_URL"] = "https://api.lockingaccelerator.com"

  ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"] = "svisamsetty@navaratan.com, groovepacker+importfail@gmail.com, kcpatel006@gmail.com"
  ENV["PRODUCTS_IMPORT_EMAILS"] = "svisamsetty@navaratan.com, kcpatel006@gmail.com, groovepacker@gmail.com"
  ENV["PRODUCTS_IMPORT_COMPLETE_EMAILS"] = "kcpatel006@gmail.com"

  #Campaign-Monitoring API_KEY and CLIENT_ID
  ENV['CAMPAIGN_MONITOR_API_KEY'] = "0319589f90c1b2f6a1034c2d8cd47604"
  ENV['CAMPAIGN_MONITOR_CLIENT_ID'] = "1c1a38f864c174b42eb2ebcd613b6969"
  #List Name - Leads
  ENV['CAMPAIGN_MONITOR_LEADS_LIST_ID'] = "38a81f16cbea2aaa7eccef85a1381931"
  #List Name - New Customers
  ENV['CAMPAIGN_MONITOR_NEW_CUSTOMER_LIST_ID'] = "f8a09dc725586f011d56a0b4e5409317"
  #List Name - All Customers
  ENV['CAMPAIGN_MONITOR_ALL_CUSTOMERS_LIST_ID'] = "8f138927c7a231368f3f6fa8e741c878"
end
