# frozen_string_literal: true

namespace :cssa do
  desc 'Calls Analytic Server And Initiates The Data Models'

  task initiate_data_model: :environment do
    tenants = Tenant.all
    tenants.each do |_tenant|
      HTTParty.post("#{ENV['GROOV_ANALYTIC_URL']}/dashboard/update_data_model")
    rescue Exception => e
      puts e.message
    end
  end
end
