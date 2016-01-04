namespace :cssa do
  desc "Calls Analytic Server And Initiates The Data Models"

  task :initiate_data_model => :environment do
    tenants = Tenant.all
    # tenants.each do |tenant|
      begin
        HTTParty.get("#{ENV["GROOV_ANALYTIC"]}/dashboard/update_data_model",
          query: {tenant_name: 'groovelytics_development'})
      rescue Exception => e
        puts e.message
      end
    # end
  end
end
