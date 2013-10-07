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

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5
  ENV['AMAZON_MWS_ACCESS_KEY_ID'] = "AKIAJRXZUVPLLINJ2EUQ"
  ENV['AMAZON_MWS_SECRET_ACCESS_KEY'] = "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"

  ENV['EBAY_APP_ID'] = "Navarata-c04e-41cb-a923-77755ae59a0f"
  ENV['EBAY_CERT_ID'] = "596cd688-b754-49b1-8b92-a3c393caed49"
  ENV['EBAY_DEV_ID'] = "568a739c-a13d-40e5-922a-6e3ecc652d9d"
  ENV['EBAY_RU_NAME'] = "Navaratan_Techn-Navarata-c04e-4-kglxwbl"
  ENV['EBAY_SANDBOX_MODE'] = "NO"
  # ENV['EBAY_APP_ID'] = "Navarata-607d-4a45-8a42-51c735a57026"
  # ENV['EBAY_CERT_ID'] = "86380834-e449-4dd9-b19f-748b4625533d"
  # ENV['EBAY_DEV_ID'] = "568a739c-a13d-40e5-922a-6e3ecc652d9d"
  # ENV['EBAY_RU_NAME'] = "Navaratan_Techn-Navarata-607d-4-ltqij"
  # ENV['EBAY_SANDBOX_MODE'] = "YES"
end
