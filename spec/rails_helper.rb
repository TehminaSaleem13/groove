# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'
require 'database_cleaner'
require 'webmock/rspec'

# Add additional requires below this line. Rails is not loaded until this point!

# prevent Test::Unit's AutoRunner from executing during RSpec's rake task
Test::Unit.run = true if defined?(Test::Unit) && Test::Unit.respond_to?(:run=)

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
Dir[Rails.root.join('lib/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.include Devise::Test::ControllerHelpers, type: :controller
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{Rails.root.join('spec/fixtures')}"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  config.expect_with :rspec do |c|
    # Disable the `expect` sytax...
    # c.syntax = :should

    # ...or disable the `should` syntax...
    # c.syntax = :expect

    # ...or explicitly enable both
    c.syntax = %i[should expect]
  end
  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs

  config.after do
    $redis.flushdb
  end

  config.around(:each, :delayed_job) do |example|
    old_value = Delayed::Worker.delay_jobs
    Delayed::Worker.delay_jobs = true
    Delayed::Job.destroy_all

    example.run

    Delayed::Worker.delay_jobs = old_value
  end
  DatabaseCleaner.strategy = :truncation

  # then, whenever you need to clean the DB
  DatabaseCleaner.clean
  config.infer_spec_type_from_file_location!
end
