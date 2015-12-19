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
    :address => "smtp.mandrillapp.com",
    :port => 587,  
    :authentication => "plain",
    :enable_starttls_auto => true,
    :domain => 'groovepacker.com',
    :user_name => 'groovepacker@gmail.com',
    :password => 'ckWnOifHhLOJRiqZQ-ZRKA',
    :openssl_verify_mode  => 'none'
  }
  $redis = Redis.new(:host => 'groov-staging-db', :port=> 6379)
  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  ENV['AMAZON_MWS_ACCESS_KEY_ID'] = "AKIAJ4VZ2GY7HZUL277Q"
  ENV['AMAZON_MWS_SECRET_ACCESS_KEY'] = "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"

  ENV['EBAY_APP_ID'] = "DSO698331-163d-4ffd-be1a-0eceb5ae5be"
  ENV['EBAY_CERT_ID'] = "a5b0c5cb-7863-4ade-92f0-1331997def8c"
  ENV['EBAY_DEV_ID'] = "353bd404-651b-4431-955d-25e0a0c8140f"
  ENV['EBAY_RU_NAME'] = "DSO-DSO698331-163d--otkbuvijt"
  ENV['EBAY_SANDBOX_MODE'] = "NO"

  ENV['SHIPSTATION_USERNAME'] = "dreadhead"
  ENV['SHIPSTATION_PASSWORD'] = "g8J$v5KLoP"

  ENV['SHOPIFY_API_KEY'] = "74bb4366e7b9b9abfd246ff8eed41201"
  ENV['SHOPIFY_SHARED_SECRET'] = "d0b33de5f8fadb93ff392505f449402c"
  ENV["SHOPIFY_REDIRECT_HOST"] = "barcodepacker.com"

  ENV['BC_CALLBACK_HOST'] = "admin.barcodepacker.com"
  ENV['BC_CLIENT_ID'] = "as4fwmwmb2n3w2yolabja7yv9weumoj"
  ENV['BC_CLIENT_SECRET'] = "15a94s1mhhczf79v2lpj79btw443u3w"
  ENV['BC_APP_URL'] = "https://store-1pslcuh.mybigcommerce.com/manage/marketplace/apps/4907"

  # Stripe production keys
  ENV['STRIPE_API_KEY'] = "sk_test_4QS2OJ8BkMWcuzCWrHrKGlz9"
  ENV['STRIPE_PUBLIC_KEY'] = "pk_test_4QS2UN3famIPlHtp2Q7ykpDf"
  ENV['HOST_NAME'] = 'barcodepacker.com'
  ENV['ONE_TIME_PAYMENT'] = '50000'
  ENV['BC_ONE_TIME_PAYMENT'] = '0'

  ENV['S3_ACCESS_KEY_ID'] = 'AKIAIBDKVKEM7HNZUQAA'
  ENV['S3_ACCESS_KEY_SECRET'] = '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'
  ENV['S3_BUCKET_NAME'] = 'groove-staging'
  ENV['S3_BASE_URL'] = 'https://s3-us-west-2.amazonaws.com/groove-staging'

  #Feature Variables
  ENV['DASHBOARD_ENABLE'] = 'YES'

  ENV["SITE_HOST"] = "barcodepacker.com"
end
