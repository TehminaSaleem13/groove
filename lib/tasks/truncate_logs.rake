namespace :doo do
  desc 'Truncate Logs'
  task truncate_logs: :environment do
    system `truncate -s 0 log/production.log`
    system `truncate -s 0 log/staging.log`
  end
end
