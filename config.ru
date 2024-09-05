# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

run Rails.application
Rails.application.load_server

DelayedJobWeb.use Rack::Auth::Basic do |username, password|
  username == 'groovedev' && password == 'jobgroove*&!!'
end
