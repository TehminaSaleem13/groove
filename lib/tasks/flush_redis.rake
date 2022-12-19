# frozen_string_literal: true

namespace :doo do
  desc 'clear redis data'
  task clear_redis: :environment do
    process = `redis-cli -h gp-new-upgrade-redis-001.wrs3e6.0001.use1.cache.amazonaws.com -p 6379 flushall` # if Rails.env = "production"
  end
end
