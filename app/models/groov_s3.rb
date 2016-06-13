class GroovS3
  class << self
    require 's3'
    @bucket = nil

    def create(tenant, file, content_type = 'application/octet-stream', privacy = :public_read)
      object = self.bucket.objects.build(tenant+'/'+file)
      object.acl = privacy
      object.content_type = content_type
      object
    end

    def save(object, data)
      object.content = data
      save = object.save
      save
    end

    #TODO: refactor csv, pdf, image into their own classes later

    def create_csv(tenant, type, store_id, data, privacy = :private)
      object = self.create(tenant, "csv/#{type}.#{store_id}.csv", 'text/csv', privacy)
      self.save(object, data)
    end

    def create_teapplix_csv(dir, name, data, privacy = :public_read)
      object = self.create(dir, "#{name}.csv", 'text/csv', privacy)
      self.save(object, data)
    end

    def find_teapplix_csv(dir, name)
      begin
        object = self.bucket.objects.find(dir+"/#{name}.csv")
        return object
      rescue S3::Error::NoSuchKey => e
        return nil
      end
    end

    def find_csv(tenant, type, store_id)
      begin
        object = self.bucket.objects.find(tenant+"/csv/#{type}.#{store_id}.csv")
        return object
      rescue S3::Error::NoSuchKey => e
        return nil
      end
    end

    def create_export_csv(tenant, file_name, data)
      object = self.create(tenant,"export_csv/#{file_name}",'text/csv', :public_read)
      self.save(object, data)
      object
    end

    def find_export_csv(tenant, file_name)
      require 'aws-sdk'
      begin
        creds = Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET'])
        s3 = Aws::S3::Resource.new(region:ENV['S3_BUCKET_REGION'], credentials: creds)
        object = s3.bucket(ENV['S3_BUCKET_NAME']).object(tenant+"/export_csv/#{file_name}")
        # object = self.bucket.objects.find(tenant+"/export_csv/#{file_name}")
        put_url = object.presigned_url(:put, acl: 'public-read', expires_in: 3600 * 24)
        return object.public_url
      rescue Exception => e
        return nil
      end
    end

    def create_order_backup(tenant, file_name, data)
      object = self.create(tenant, "deleted_orders/#{file_name}", 'text/sql', :private)
      self.save(object, data)
    end

    def get_bucket
      creds = Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET'])
      s3 = Aws::S3::Resource.new(region:ENV['S3_BUCKET_REGION'], credentials: creds)
      s3.bucket(ENV['S3_BUCKET_NAME'])
    end

    def get_file(file_name)
      begin
        puts "file_name: " + file_name
        object = self.bucket.objects.find(file_name)
        puts "object: " + object.inspect
        return object
      rescue S3::Error::NoSuchKey => e
        puts e.message
        return nil
      end
    end

    def create_pdf(tenant, file_name, data)
      object = self.create(tenant, "pdf/#{file_name}", 'application/pdf', :public_read)
      self.save(object, data)
    end

    def create_image(tenant, file_name, data, content_type)
      object = self.create(tenant, "image/#{file_name}", content_type, :public_read)
      self.save(object, data)
    end


    def bucket
      if @bucket.nil?
        service = S3::Service.new(
          :access_key_id => ENV['S3_ACCESS_KEY_ID'],
          :secret_access_key => ENV['S3_ACCESS_KEY_SECRET']
        )
        @bucket = service.buckets.find(ENV['S3_BUCKET_NAME'])
      end
      @bucket
    end
  end
end
