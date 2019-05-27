namespace :doo do
  desc "clear redis data"
  task :clear_redis => :environment do
    process = `redis-cli -h groove-prod3-redis.wrs3e6.ng.0001.use1.cache.amazonaws.com -p 6379 flushall` if Rails.env = "production"
  end
end
