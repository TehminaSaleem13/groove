  Airbrake.configure do |config|
    config.api_key = '3e545c7d440c1b46e79e4e141e75bf8f'
    config.host    = 'errbit.dev'
    config.port    = 3000
    config.secure  = config.port == 443
  end
