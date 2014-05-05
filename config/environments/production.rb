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
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  config.action_mailer.default_url_options = { :host => 'localhost' }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    :address => "mail.groovepacker.com",
    :authentication=> "plain",
    :enable_starttls_auto => true,
    :user_name => 'app@groovepacker.com',
    :password => '1packermail!'
  }

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5
  ENV['AMAZON_MWS_ACCESS_KEY_ID'] = "AKIAJ4VZ2GY7HZUL277Q"
  ENV['AMAZON_MWS_SECRET_ACCESS_KEY'] = "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"

  ENV['EBAY_APP_ID'] = "DSO698331-163d-4ffd-be1a-0eceb5ae5be"
  ENV['EBAY_CERT_ID'] = "a5b0c5cb-7863-4ade-92f0-1331997def8c"
  ENV['EBAY_DEV_ID'] = "353bd404-651b-4431-955d-25e0a0c8140f"
  ENV['EBAY_RU_NAME'] = "DSO-DSO698331-163d--aptkv"
  ENV['EBAY_SANDBOX_MODE'] = "NO"
  # ENV['EBAY_APP_ID'] = "Navarata-607d-4a45-8a42-51c735a57026"
  # ENV['EBAY_CERT_ID'] = "86380834-e449-4dd9-b19f-748b4625533d"
  # ENV['EBAY_DEV_ID'] = "568a739c-a13d-40e5-922a-6e3ecc652d9d"
  # ENV['EBAY_RU_NAME'] = "Navaratan_Techn-Navarata-607d-4-ltqij"
  # ENV['EBAY_SANDBOX_MODE'] = "YES"
end
