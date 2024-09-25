# frozen_string_literal: true

namespace :doo do
  desc 'Truncate Logs'
  task truncate_logs: :environment do
    next if $redis.get('truncate_logs')

    $redis.set('truncate_logs', true)
    $redis.expire('truncate_logs', 180)
    
    system `truncate -s 0 log/production.log`
    system `truncate -s 0 log/staging.log`
  end
end
