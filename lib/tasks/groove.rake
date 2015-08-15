namespace :groove do
  desc 'Delete a tenant'

  task :del_tenant => :environment do |args|
    options = {}
    OptionParser.new(args) do |opts|
      opts.banner = 'Usage: groove:del_tenants -- [options]'

      opts.on('-t', '--tenant {tenant_name}', 'Tenant Name', String) do |tenant|
        options[:tenant] = tenant
      end
    end.parse!
    unless options[:tenant].nil?

      del_tenant = Tenant.find_by_name(options[:tenant])
      puts 'Owner Tenant is: '+Apartment::Tenant.current.to_s
      if del_tenant.nil?
        puts "Tenant #{options[:tenant]} not found"
      else
        begin
          Apartment::Tenant.drop(options[:tenant])
        rescue Exception => e
          puts e.message
        else
          puts 'Removed tenant '+options[:tenant]+' Database'
        end
        if del_tenant.destroy
          puts 'Removed '+options[:tenant]+' from tenants table'
        end
      end

    end
    exit(1)
  end

  task :upgrade => :environment do
    Tenant.all.each do |tenant|
      begin
        Apartment::Tenant.process(tenant.name) do
          puts 'Upgrading Tenant: '+Apartment::Tenant.current.to_s
          #Add upgrade code to run for every tenant after this line
          #Add upgrade code to run for every tenant before this line
        end
      rescue Exception => e
        puts e.message
        if e.message == 'Cannot find tenant '+tenant.name
          puts 'Trying to delete missing tenant '+tenant.name
          if tenant.destroy
            puts 'Success!'
          end
        end
      end
    end

    # Add all non-tenant upgrade code after this line
    # Add all non-tenant upgrade code before this line
    exit(1)
  end

  task :fix_inventory => :environment do
    Tenant.all.each do |tenant|
      begin
        Apartment::Tenant.process(tenant.name) do
          puts 'Upgrading Tenant: '+Apartment::Tenant.current.to_s
          #Add upgrade code to run for every tenant after this line
          general_setting = GeneralSetting.all.first
          bulk_action = Groovepacker::Inventory::BulkActions.new
          inventory_data = []
          if general_setting.inventory_tracking?
            product_inventory_warehouses = ProductInventoryWarehouses.all
            product_inventory_warehouses.each do |single_warehouse|
              inventory_data << {id: single_warehouse.id, quantity_on_hand: single_warehouse.quantity_on_hand}
            end
            bulk_action.do_unprocess_all
            product_inventory_warehouses = nil
            Order.all.each do |single_order|
              bulk_action.do_process_single(single_order)
            end
            inventory_data.each do |single_warehouse|
              product_inv = ProductInventoryWarehouses.find(single_warehouse[:id])
              product_inv.quantity_on_hand = single_warehouse[:quantity_on_hand]
              product_inv.save
            end
          else
            bulk_action.do_unprocess_all
          end
          #Add upgrade code to run for every tenant before this line
        end
      rescue Exception => e
        puts e.message
        if e.message == 'Cannot find tenant '+tenant.name
          puts 'Trying to delete missing tenant '+tenant.name
          if tenant.destroy
            puts 'Success!'
          end
        end
      end
    end

    # Add all non-tenant upgrade code after this line
    # Add all non-tenant upgrade code before this line
    exit(1)
  end

  task :long_spec do
    begin
      webdriver_pid = fork do
        Rake::Task['protractor:webdriver'].invoke
      end
      rails_server_pid = fork do
        Rake::Task['protractor:rails'].invoke
      end
      puts "webdriver PID: #{webdriver_pid}".yellow.bold
      puts "Rails Server PID: #{rails_server_pid}".yellow.bold
      puts 'Waiting for servers to finish starting up....'
      sleep 6
      Rake::Task['groove:spec'].invoke
    rescue Exception => e
      puts e
    ensure
      sleep 1
      Process.kill 'TERM', webdriver_pid
      Process.kill 'TERM', rails_server_pid
      Process.wait webdriver_pid
      Process.wait rails_server_pid
      puts 'Waiting to shut down cleanly.........'.yellow.bold
      sleep 5
      Rake::Task['protractor:kill'].invoke
      exit(1)
    end
  end

  task :spec do
    #Added cleanup here to delay startup some more while webrick loads
    #Rake::Task['protractor:cleanup'].invoke
    system 'protractor spec/javascripts/protractor/conf.js'
    exit(0)
  end
end
