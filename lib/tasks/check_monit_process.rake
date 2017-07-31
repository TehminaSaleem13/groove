namespace :doo do
  desc "Check the jobs which failed or stopped in last 5 minutes"
  task :check_monit_process => :environment do
    process = `ps aux | grep monit`
    if process.include?("/usr/bin/monit -c /etc/monit/monitrc")
       `sudo service monit restart`
    end
  end
end
