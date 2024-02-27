# frozen_string_literal: true

namespace :doo do
  desc 'import shopify orders from each active store at every 10 mins'
  task import_shopify_orders_every_ten_mins: :environment do
    ImportOrders.new.delay(priority: 95, queue: "import_shopify_orders_every_ten_mins").import_shopify_orders_every_ten_mins
  end
end
