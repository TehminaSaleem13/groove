# frozen_string_literal: true
class GroovS3
  class << self
    require 's3'
    require 'csv'

    @bucket = nil

    def create(tenant, file, content_type = 'application/octet-stream', privacy = :public_read)
      object = bucket.objects.build("#{tenant}/#{file}")
      object.acl = privacy
      object.content_type = content_type
      object
    end

    def save(object, data)
      object.content = data
      object.save
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
      bucket.objects.find(dir + "/#{name}.csv")
    rescue S3::Error::NoSuchKey => e
      nil
    end

    def find_csv(tenant, type, store_id)
      bucket.objects.find(tenant + "/csv/#{type}.#{store_id}.csv")
    rescue S3::Error::NoSuchKey => e
      nil
    end

    def create_export_csv(tenant, file_name, data)
      object = create(tenant, "export_csv/#{file_name}", 'text/csv', :public_read)
      save(object, data)
      object
    end

    def find_export_csv(tenant, file_name)
      creds = Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET'])
      s3 = Aws::S3::Resource.new(region: ENV['S3_BUCKET_REGION'], credentials: creds)
      object = s3.bucket(ENV['S3_BUCKET_NAME']).object(tenant + "/export_csv/#{file_name}")
      # object = self.bucket.objects.find(tenant+"/export_csv/#{file_name}")
      put_url = object.presigned_url(:put, acl: 'public-read', expires_in: 3600 * 24)
      object.public_url
    rescue Exception => e
      nil
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
      bucket.objects.find(tenant + "/orders/#{name}.xml")
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

def upload_images_to_s3(folder_path, s3_folder = "ferroconcepts/image/")
  s3 = Aws::S3::Resource.new(
    credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
    region: ENV['S3_BUCKET_REGION']
  )

  bucket = s3.bucket(ENV['S3_BUCKET_NAME'])
  public_urls = []
  allowed_extensions = ["png", "jpg", "jpeg", "gif"]
  csv_data = [["File Name", "Image URL"]]  # CSV Header

  Dir.glob("#{folder_path}/**/*.{#{allowed_extensions.join(',')}}").each do |file_path|
    file_name = File.basename(file_path)
    s3_key = "#{s3_folder}#{file_name}"  

    obj = bucket.object(s3_key)
    obj.upload_file(file_path, acl: 'public-read')

    # Construct correct public URL
    image_url = "https://#{bucket.name}.s3.amazonaws.com/#{s3_key}"
    public_urls << image_url
    csv_data << [file_name, image_url]

    puts "✅ Uploaded #{file_name} → #{image_url}"
  end

  timestamp = Time.now.strftime("%d_%b_%Y_%I_%M_%S_%Z")
  csv_filename = "gp55_#{timestamp}.csv"
  csv_file_path = File.join(folder_path, csv_filename)

  CSV.open(csv_file_path, "w") do |csv|
    csv_data.each { |row| csv << row }
  end

  puts "📄 CSV file created: #{csv_file_path}"

  csv_s3_key = "ferroconcepts/csv/#{csv_filename}"
  bucket.object(csv_s3_key).upload_file(csv_file_path, acl: 'public-read')
  puts "📤 CSV uploaded to S3: s3://#{bucket.name}/#{csv_s3_key}"

  public_urls
end

    

    # This method will generate the URL for the export CSV files and also upload the generated file in S3.
    def get_csv_export(file_name)
      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
        region: ENV['S3_BUCKET_REGION']
      )
      obj = s3.bucket(ENV['S3_BUCKET_NAME']).object("public/pdfs/#{file_name}")
      obj.upload_file('public/pdfs/' + file_name, acl: 'public-read')
      obj.public_url
    end

    def get_csv_export_exception(file_name)
      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
        region: ENV['S3_BUCKET_REGION']
      )
      obj = s3.bucket(ENV['S3_BUCKET_NAME']).object("public/csv/#{file_name}")
      obj.upload_file('public/csv/' + file_name, acl: 'public-read')
      obj.public_url
    end
    
    def create_sound_from_system(tenant, file_paths, user_name, sound_type, content_type = 'audio/mpeg', privacy = :public_read)
      valid_types = ['correct_scan', 'error_scan', 'order_done']
    
      unless valid_types.include?(sound_type)
        raise ArgumentError, "Invalid sound type. Must be one of: #{valid_types.join(', ')}"
      end
    
      file_paths = Array(file_paths)
      public_urls = []
    
      s3 = Aws::S3::Client.new(
        access_key_id: ENV['S3_ACCESS_KEY_ID'],
        secret_access_key: ENV['S3_ACCESS_KEY_SECRET'],
        region: ENV['S3_BUCKET_REGION']
      )
    
      bucket_name = ENV['S3_BUCKET_NAME']
      region = ENV['S3_BUCKET_REGION']
    
      file_paths.each do |file|
        raise "File not found: #{file.original_filename}" unless file.tempfile && File.exist?(file.tempfile.path)
    
        object_key = File.join(user_name.to_s, "sounds", sound_type, file.original_filename)
        s3_key = "#{tenant}/#{object_key}"  # Full key in S3
        
          file_data = File.read(file.tempfile.path)
          object = create(tenant, object_key)
          if object.exists?
            puts "⏩ Skipping #{file.original_filename} (Already uploaded at s3://#{tenant}/#{object_key})"
            return { status: false, message: "File already exists" }
          end
          save(object, file_data)
    
        public_url = "https://#{bucket_name}.s3.#{region}.amazonaws.com/#{tenant}/#{object_key}"
        public_urls << public_url
      end
    
      public_urls
    end

    def upload_sounds_to_s3(local_folder_path)
      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
        region: ENV['S3_BUCKET_REGION']
      )
      bucket = s3.bucket(ENV['S3_BUCKET_NAME'])
    
      response = bucket.client.list_objects_v2(bucket: bucket.name, delimiter: '/')
      folders = response.common_prefixes.map { |prefix| prefix.prefix.chomp('/') } if response.common_prefixes
    
      return puts "❌ No folders found in the bucket!" unless folders&.any?
    
      Dir.glob("#{local_folder_path}/*.mp3").each do |file_path|
        file_name = File.basename(file_path)
        
        case file_name
        when /^correct/
          sound_type = "correct_scan"
        when /^error/
          sound_type = "error_scan"
        when /^done/
          sound_type = "order_done"
        else
          puts "⚠️ Skipping #{file_name} (Unknown prefix)"
          next
        end
    
        folders.each do |folder|
          s3_key = "#{folder}/sounds/#{sound_type}/#{file_name}"
          obj = bucket.object(s3_key)
    
          if obj.exists?
            puts "⏩ Skipping #{file_name} (Already uploaded at s3://#{bucket.name}/#{s3_key})"
            next
          end
    
          obj.upload_file(file_path, acl: 'public-read')
    
          puts "✅ Uploaded #{file_name} to s3://#{bucket.name}/#{s3_key}"
        end
      end
    end

    def get_sounds_export(user_name)
      valid_types = ['correct_scan', 'error_scan', 'order_done']
    
      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
        region: ENV['S3_BUCKET_REGION']
      )
    
      bucket_name = ENV['S3_BUCKET_NAME']
      tenant = Apartment::Tenant.current 
      content_types = {}
    
      valid_types.each do |sound_type|
        prefixes = [
          "#{tenant}/#{user_name}/sounds/#{sound_type}/",
          "#{tenant}/sounds/#{sound_type}/"
        ]
    
        prefixes.each do |prefix|
          puts "Scanning S3 under prefix: #{prefix}"
    
          objects = s3.bucket(bucket_name).objects(prefix: prefix)
          next if objects.none?
    
          content_types[sound_type] ||= []
    
          objects.each do |obj_summary|
            obj = s3.bucket(bucket_name).object(obj_summary.key)
    
            content_types[sound_type] << {
              content_type: obj.content_type || 'unknown',
              url: obj.public_url,
              filename: File.basename(obj_summary.key),
              tenant_name: tenant,
              user_name: user_name,
              source: prefix.include?(user_name) ? 'user' : 'global'
            }
          end
        end
      end
    
      content_types
    end   
    
    def delete_object_sound(tenant, sound_type, file_name, user_name)
      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_ACCESS_KEY_SECRET']),
        region: ENV['S3_BUCKET_REGION']
      )
    
      bucket_name = ENV['S3_BUCKET_NAME']
      s3_object_key = "#{tenant}/#{user_name}/sounds/#{sound_type}/#{file_name}" # ✅ Corrected path
      object = s3.bucket(bucket_name).object(s3_object_key)
    
      if object.exists?
        begin
          object.delete
          return { status: 'success', message: "File '#{file_name}' deleted successfully from '#{sound_type}'." }
        rescue Aws::S3::Errors::ServiceError => e
          return { status: 'error', message: "Failed to delete file '#{file_name}': #{e.message}" }
        end
      else
        return { status: 'error', message: "The file '#{file_name}' was not found in '#{sound_type}'." }
      end
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
