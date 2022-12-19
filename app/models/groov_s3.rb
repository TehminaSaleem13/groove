# frozen_string_literal: true

class GroovS3
  class << self
    require 's3'
    @bucket = nil

    def create(tenant, file, content_type = 'application/octet-stream', privacy = :public_read)
      object = bucket.objects.build("#{tenant}/#{file}")
      object.acl = privacy
      object.content_type = content_type
      object
    end

    def save(object, data)
      object.content = data
      save = object.save
      save
    end

    # TODO: refactor csv, pdf, image into their own classes later

    def create_csv(tenant, type, store_id, data, privacy = :private)
      object = create(tenant, "csv/#{type}.#{store_id}.csv", 'text/csv', privacy)
      save(object, data)
    end

    def create_public_csv(tenant, type, store_id, data, privacy = :public_read)
      object = create(tenant, "csv/#{type}.#{store_id}.csv", 'text/csv', privacy)
      save(object, data)
      object
    end

    def create_public_zip(tenant, data, privacy = :public_read)
      object = create(tenant, 'products/restore.zip', 'zip', privacy)
      save(object, data)
      object
    end

    def create_teapplix_csv(dir, name, data, privacy = :public_read)
      object = create(dir, "#{name}.csv", 'text/csv', privacy)
      save(object, data)
    end

    def delete_object(key)
      object = bucket.objects.find(key)
      object.destroy
    rescue S3::Error::NoSuchKey => e
      false
    end

    def find_teapplix_csv(dir, name)
      object = bucket.objects.find(dir + "/#{name}.csv")
      object
    rescue S3::Error::NoSuchKey => e
      nil
    end

    def find_csv(tenant, type, store_id)
      object = bucket.objects.find(tenant + "/csv/#{type}.#{store_id}.csv")
      object
    rescue S3::Error::NoSuchKey => e
      nil
    end

    def create_export_csv(tenant, file_name, data)
      object = create(tenant, "export_csv/#{file_name}", 'text/csv', :public_read)
      save(object, data)
      object
    end

    def find_export_csv(tenant, file_name)
      require 'aws-sdk'
      begin
        creds = Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET'])
        s3 = Aws::S3::Resource.new(region: ENV['S3_BUCKET_REGION'], credentials: creds)
        object = s3.bucket(ENV['S3_BUCKET_NAME']).object(tenant + "/export_csv/#{file_name}")
        # object = self.bucket.objects.find(tenant+"/export_csv/#{file_name}")
        put_url = object.presigned_url(:put, acl: 'public-read', expires_in: 3600 * 24)
        return object.public_url
      rescue Exception => e
        return nil
      end
    end

    def create_order_backup(tenant, file_name, data)
      object = create(tenant, "deleted_orders/#{file_name}", 'text/sql', :private)
      save(object, data)
    end

    def create_order_xml(tenant, name, data, privacy = :private)
      date = Time.current.strftime('%Y-%m-%d')
      object = create(tenant, "orders/#{date}-#{name}", 'text/xml', privacy)
      "orders/#{date}-#{name}" if save(object, data)
    end

    def find_order_xml(tenant, name)
      object = bucket.objects.find(tenant + "/orders/#{name}.xml")
      object
    rescue S3::Error::NoSuchKey => e
      nil
    end

    def get_bucket
      creds = Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET'])
      s3 = Aws::S3::Resource.new(region: ENV['S3_BUCKET_REGION'], credentials: creds)
      s3.bucket(ENV['S3_BUCKET_NAME'])
    end

    def get_file(file_name)
      puts 'file_name: ' + file_name
      object = bucket.objects.find(file_name)
      puts 'object: ' + object.inspect
      object
    rescue S3::Error::NoSuchKey => e
      puts e.message
      nil
    end

    def create_pdf(tenant, file_name, data)
      object = create(tenant, "pdf/#{file_name}", 'application/pdf', :public_read)
      save(object, data)
    end

    def create_log(tenant, file_name, data)
      object = create(tenant, "log/#{file_name}", 'text', :public_read)
      save(object, data)
    end

    def create_receiving_label_pdf(tenant, file_name, data)
      object = create(tenant, "pdf/#{file_name}", 'application/pdf', :public_read)
      save(object, data)
      begin
        Rails.root.join('public', 'pdfs', "#{file_name}.pdf").delete
      rescue StandardError
        nil
      end
      object
    end

    def create_image(tenant, file_name, data, content_type)
      object = create(tenant, "image/#{file_name}", content_type, :public_read)
      save(object, data)
    end

    # This method will generate the URL for the export CSV files and also upload the generated file in S3.
    def get_csv_export(file_name)
      require 'aws-sdk'
      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
        region: ENV['S3_BUCKET_REGION']
      )
      obj = s3.bucket(ENV['S3_BUCKET_NAME']).object("public/pdfs/#{file_name}")
      obj.upload_file('public/pdfs/' + file_name, acl: 'public-read')
      obj.public_url
    end

    def get_csv_export_exception(file_name)
      require 'aws-sdk'
      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
        region: ENV['S3_BUCKET_REGION']
      )
      obj = s3.bucket(ENV['S3_BUCKET_NAME']).object("public/csv/#{file_name}")
      obj.upload_file('public/csv/' + file_name, acl: 'public-read')
      obj.public_url
    end

    def bucket
      if @bucket.nil?
        service = S3::Service.new(
          access_key_id: ENV['S3_ACCESS_KEY_ID'],
          secret_access_key: ENV['S3_ACCESS_KEY_SECRET']
        )
        @bucket = service.buckets.find(ENV['S3_BUCKET_NAME'])
      end
      @bucket
    end
  end
end
