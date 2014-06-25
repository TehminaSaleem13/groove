namespace :store do
  desc "import orders from each and every store"

  task :import_ordrs => :environment do
    # DeleteFiles.delay(:run_at => 20.seconds.from_now).delete_pdfs
    ImportOrders.delay(:run_at => 10.seconds.from_now).import_ordrs
  end
end