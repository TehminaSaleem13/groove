namespace :import do
  desc "delete all files created before certain time"

  task :amazon_orders => :environment do
    stores = Store.where(:store_type=>'amazon')

    if stores.length > 0
      context = Groovepacker::Store::Context.new(
        Groovepacker::Store::Handlers::AmazonHandler.new(stores.first))
      puts context.import_orders
    else
      puts "no stores available for amazon"
    end
  end
end