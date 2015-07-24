namespace :scan_pack do
  desc "update scan_pack start time"

  task :initiate_scan_start_time => :environment do
    Tenant.all.each do |tenant|
      begin
      Apartment::Tenant.process(tenant.name) do
        #Groovepacker::Dashboard::Stats::LeaderBoard.new.compute_leader_board
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
  end

  task :initiate_incorrect_scan_count => :environment do
    Tenant.all.each do |tenant|
      begin
      Apartment::Tenant.process(tenant.name) do
        puts 'Upgrading Tenant: '+Apartment::Tenant.current.to_s
        puts "OrderCount:" + Order.where(status: 'scanned').count.to_s
        Order.where(status: 'scanned').each do |order|
          order.inaccurate_scan_count = rand(0..1)
          order.save
        end
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
  end

  task :initiate_leader_board=> :environment do
    Tenant.all.each do |tenant|
      begin
      Apartment::Tenant.process(tenant.name) do
        Groovepacker::Dashboard::Stats::LeaderBoardStats.new.compute_leader_board
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
  end

end