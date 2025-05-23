# frozen_string_literal: true

namespace :cta do
  desc 'Creates Tenants In Groovelytics Server With Same Names As In AppServer'

  task create_tenants: :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      HTTParty::Basement.default_options.update(verify: false)
      HTTParty.post("#{ENV['GROOV_ANALYTIC_URL']}/tenants",
                    query: { tenant_name: tenant.name })
    rescue Exception => e
      puts e.message
      break
    ensure
      HTTParty::Basement.default_options.update(verify: true)
    end
  end
end
