namespace :tr do
  desc "Test to verify that the changes reflect in dashboard"
  task :test_realtime => :environment do
    begin
      HTTParty.get("#{ENV["GROOV_ANALYTIC"]}/dashboard/test",
        query: {tenant_name: 'dhhq'})
    rescue Exception => e
      puts e.message
      break
    end
  end
end
