namespace :import do
  desc "delete all files created before certain time"

  task :amazon_orders => :environment do
    stores = Store.all

    stores.each do |store|
      if store.store_type == 'Amazon1'
        context = Groovepacker::Store::Context.new(
          Groovepacker::Store::Handlers::AmazonHandler.new(store))
        context.import_orders
      elsif store.store_type == 'Ebay'
        context = Groovepacker::Store::Context.new(
          Groovepacker::Store::Handlers::EbayHandler.new(store))
        puts context.import_orders.inspect
      end
    end
  end
end