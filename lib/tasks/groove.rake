namespace :groove do
  desc 'Delete a tenant'

  task :del_tenant => :environment do |args|
    options = {}
    OptionParser.new(args) do |opts|
      opts.banner = 'Usage: groove:del_tenants -- [options]'

      opts.on('-t','--tenant {tenant_name}','Tenant Name',String) do |tenant|
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
          rescue Exception=>e
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

        Order.all.each do |single_order|
          if Order.where(:increment_id => single_order.increment_id).length > 1
            single_order.destroy
          end
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
    puts 'Cleaning and seeding test db'.green.bold
    Rake::Task['protractor:cleanup'].invoke
    puts 'Starting Protractor tests'.green.bold
    system 'protractor spec/javascripts/protractor/conf.js'
    puts 'Finished Running Protractor Tests! Bye!'.green.bold
    exit(1)
  end
end
