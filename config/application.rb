require_relative 'boot'

require 'rails/all'
require 'apartment/elevators/subdomain'

require 'csv'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Groovepacks
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.autoloader = :classic

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    config.time_zone = 'UTC'

    # config.eager_load_paths << Rails.root.join("extras")
    # Autoload lib/ folder including all subdirectories
    config.eager_load_paths << Rails.root.join('lib')
    config.autoload_paths += Dir[Rails.root.join('lib')]
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
    config.middleware.use Apartment::Elevators::Subdomain
    config.assets.paths << Rails.root.join('app/assets/fonts')
    config.assets.paths << Rails.root.join('vendor/assets/components')
    config.assets.precompile += %w[*.png *.jpg *.jpeg *.gif *.woff *.ttf *.svg]

    config.autoload_paths += Dir[Rails.root.join('app/models/concerns/**/')]
    config.autoload_paths += Dir[Rails.root.join('app/controllers/concerns/**/')]

    # To enable Cross-Origin requests
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i[get post delete put patch options]
      end
    end

    # TODO: Cleanup redundant except time_zones_list
    config.time_zones_list = YAML.safe_load(File.open(Rails.root.join('config/time_zones_list.yml')))
    config.time_zones = YAML.safe_load(File.open(Rails.root.join('config/time_zones.yml')))
    config.time_zone_names = YAML.safe_load(File.open(Rails.root.join('config/time_zone_names.yml')))
    config.tz_abbreviations = YAML.safe_load(File.open(Rails.root.join('config/tz_abbreviations.yml')))

    config.active_job.queue_adapter = :delayed_job

    # Allow CSV Map to be serialized as Hash
    config.active_record.yaml_column_permitted_classes = [Symbol, ActiveSupport::HashWithIndifferentAccess, ActionController::Parameters]
  end
end
