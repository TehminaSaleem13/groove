namespace :gob do
  desc "import data from backup file from s3 bucket"

  task :get_order_backups => :environment do
    puts "get_order_backups..."
    tenant = Apartment::Tenant.current
    bucket = GroovS3.get_bucket
    count = bucket.objects(prefix: 'dhhq/deleted_orders/').count
    puts "count: " + count.to_s
    bucket.objects(prefix: 'dhhq/deleted_orders/').each do |obj|
      puts obj.key
      file = GroovS3.get_file(obj.key)
      puts "file: " + file.inspect
      data = file.content
      data = eval(data)
      data.each do |d|
        puts d.inspect
        break
      end
      break
    end
    exit(1)
  end
end
