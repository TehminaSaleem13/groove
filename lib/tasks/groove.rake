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
      begin
        del_tenant = Tenant.find_by_name(options[:tenant])
        if del_tenant.nil?
          puts "Tenant #{options[:tenant]} not found"
        else
          Apartment::Tenant.drop(options[:tenant])
          del_tenant.destroy
        end
      rescue Exception=>e
        puts e.message
      end
    end
    exit(1)
  end
end
