Airbrake.configure do |config|
  config.api_key = '2a7a92294f148823be87621957298e72'
  config.host    = 'groove-errbit-app-server'
  config.port    = 80
  config.secure  = config.port == 443
end
