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
            puts 'Removed tenant Database'
          end
          if del_tenant.destroy
            puts 'Removed entry from tenants table'
          end
        end

    end
    exit(1)
  end

  task :upgrade => :environment do
    Tenant.all.each do |tenant|
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
    end

    # Add all non-tenant upgrade code after this line
    # Add all non-tenant upgrade code before this line
  end
end
