namespace :gob do
  desc "import data from backup file from s3 bucket"

  task :get_order_backups, [:arg1, :arg2] => :environment do |t, args|
    args.each do |arg|
      begin
        Apartment::Tenant.switch(arg[1])
        tenant = Apartment::Tenant.current
        bucket = GroovS3.get_bucket
        count = bucket.objects(prefix: tenant + '/deleted_orders/').count
        bucket.objects(prefix: tenant + '/deleted_orders/').each do |obj|
          file = GroovS3.get_file(obj.key)
          data = file.content
          data = eval(data)
          import_obj = ImportDeletedData.new
          next if data.nil?
          data.each do |d|
            d.each do |ordo|
              next if ordo[1].empty?
              case ordo[0]
              when 'users'
                import_obj.import_users(ordo)
              when 'stores'
                import_obj.import_stores(ordo)
              when 'products'
                import_obj.import_products(ordo)
              when 'order'
                import_obj.import_orders(ordo)
              when 'order_activities'
                import_obj.import_order_activities(ordo)
              when 'order_exception'
                import_obj.import_order_exception(ordo)
              when 'order_shipping'
                import_obj.import_order_shipping(ordo)
              when 'order_serials'
                import_obj.import_order_serials(ordo)
              when 'order_items'
                import_obj.import_order_items(ordo)
              when 'order_item_kit_products'
                import_obj.import_order_item_kit_products(ordo)
              when 'order_item_order_serial_product_lots'
                import_obj.import_order_item_order_serial_product_lots(ordo)
              when 'order_item_scan_times'
                import_obj.import_order_item_scan_times(ordo)
              end
            end
          end
        end
      rescue Exception => e
        puts "Exception occurred."
        puts e.message
        puts e.backtrace.inspect
      end
    end
    exit(1)
  end
end
