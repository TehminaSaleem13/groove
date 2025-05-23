# frozen_string_literal: true

# Require whichever elevator you're using below here...
#
# require 'apartment/elevators/generic'
require 'apartment/elevators/domain'
require 'apartment/elevators/subdomain'

require 'rescued_apartment_middleware'
Rails.application.config.middleware.use Apartment::Elevators::Subdomain
Apartment::Elevators::Subdomain.prepend RescuedApartmentMiddleware
#
# Apartment Configuration
#
Apartment.configure do |config|
  # These models will not be multi-tenanted,
  # but remain in the global (public) namespace
  #
  # An example might be a Customer or Tenant model that stores each tenant information
  # ex:
  #
  # config.excluded_models = %w{Tenant}
  #
  config.excluded_models = %w[]

  # use postgres schemas?
  config.use_schemas = true
  Apartment::Elevators::Subdomain.excluded_subdomains = %w[34 35 10 100 admin]
  # use raw SQL dumps for creating postgres schemas? (only appies with use_schemas set to true)
  # config.use_sql = true

  # configure persistent schemas (E.g. hstore )
  # config.persistent_schemas = %w{ hstore }

  # add the Rails environment to database names?
  # config.prepend_environment = true
  # config.append_environment = true

  # supply list of database names for migrations to run on
  # config.tenant_names = lambda{ ToDo_Tenant_Or_User_Model.pluck :database }
  config.tenant_names = -> { Tenant.pluck :name }
  # config.tenant_names = ['test', 'test1']
  config.excluded_models = ['Delayed::Job', 'Tenant', 'Subscription', 'Coupon']
end

##
# Elevator Configuration

# Rails.application.config.middleware.use 'Apartment::Elevators::Generic', lambda { |request|
#   # TODO: supply generic implementation
# }

# Rails.application.config.middleware.use 'Apartment::Elevators::Domain'

# Rails.application.config.middleware.use 'Apartment::Elevators::Subdomain'
