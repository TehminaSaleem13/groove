namespace :import do
  desc "delete all files created before certain time"

  task :orders => :environment do
    stores = Store.all
    stores.each do |store|
      if store.store_type == 'Amazon'
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::AmazonHandler.new(store))
        puts context.import_orders.inspect
      elsif store.store_type == 'Ebay'
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::EbayHandler.new(store))
        puts context.import_orders.inspect
        puts context.import_products.inspect
      elsif store.store_type == 'Magento'
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::MagentoHandler.new(store))
        #context.import_orders.inspect
        puts context.import_products.inspect
        puts context.import_orders.inspect
      end
    end
  end
end