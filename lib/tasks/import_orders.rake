namespace :store do
  desc "import orders from each and every store at the scheduled time"

  task :import_ordrs => :environment do
    ImportOrders.delay(:run_at => 10.seconds.from_now).import_ordrs
  end
end