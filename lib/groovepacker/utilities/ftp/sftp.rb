
module FTP
  class SFTP < FTPBase
    include ApplicationHelper
  	require ('net/sftp')

    def connect
      result = self.build_result
      begin
        unless self.host.nil? || self.username.nil? || self.password.nil?
          Timeout.timeout(10) do
            if self.host.include?(":")
              host = self.host.split(":")[0]
              port = self.host.split(":")[1]
              result[:connection_obj] = Net::SFTP.start(host, self.username, :password => self.password, :port => port)
            else
              result[:connection_obj] = Net::SFTP.start(self.host, self.username, :password => self.password)
            end
          end
          return result
        else
          result[:status] = false
          result[:error_messages].push("Connection Failed. FTP Credentials are missing.")
        end
      rescue Errno::ECONNREFUSED
        result[:status] = false
        result[:error_messages].push("Connection refused.")
      rescue Timeout::Error
        result[:status] = false
        result[:error_messages].push("Operation timed out.")
      rescue SocketError
        result[:status] = false
        result[:error_messages].push("Unknown server name.")
      rescue Net::SSH::AuthenticationFailed
        result[:status] = false
        result[:error_messages].push("Authentication failed. Please check your credentails.")
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push("Error in connecting the server. Please check your credentails.")
      end
      result
    end

    def retrieve
      result = self.build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          file = find_file(connection_obj)

          if file.nil?
            result[:status] = false
            result[:error_messages].push("All CSV files on the server appear to have been imported.")
          else
            result[:success_messages].push("Connection succeeded! #{file} was found.")
          end
        else
          result[:status] = false
          response[:error_messages].each do |message|
            result[:error_messages].push(message)
          end
          return result
        end
      rescue Net::SFTP::StatusException
        result[:status] = false
        result[:error_messages].push("Please specify the correct derectory path.")
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def check_imported
      result = self.build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          folder = find_folder(connection_obj)
          if folder == true
            result[:success_messages].push("Imported Folder Ready")
          else
            result[:status] = false
            result[:error_messages].push("Unable to create the imported folder in the current directory. Please create it manually.")
          end
        else
          result[:status] = false
          response[:error_messages].each do |message|
            result[:error_messages].push(message)
          end
          return result
        end
      rescue Net::SFTP::StatusException
        result[:status] = false
        result[:error_messages].push("Please specify the correct derectory path.")
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def download(current_tenant)
      result = self.build_result
      result[:file_info] = {}
      result[:file_info][:file_path] = ''
      result[:file_info][:ftp_file_name] = ''
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          system 'mkdir', '-p', "ftp_files/#{current_tenant}"

          file_name = nil
          file_path = nil

          file = find_file(connection_obj)

          unless file.nil?
            file_name = "#{Time.current.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
            handle = connection_obj.open!("#{self.directory}/#{file}")
            connection_obj.download!("#{self.directory}/#{file}", "ftp_files/#{current_tenant}/#{file_name}")
            connection_obj.close!(handle)

            file_path = "#{Rails.root}/ftp_files/#{current_tenant}/#{file_name}"
            result[:file_info][:file_path] = file_path
            result[:file_info][:ftp_file_name] = file
          else
            result[:status] = false
            result[:error_messages].push("All CSV files on the server appear to have been imported.")
          end
        else
          result[:status] = false
          response[:error_messages].each do |message|
            result[:error_messages].push(message)
          end
          return result
        end
      rescue Net::SFTP::StatusException
        result[:status] = false
        result[:error_messages].push("All CSV files on the server appear to have been imported.")
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def update(ftp_file_name)
      return
      result = self.build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          new_file = rename_file(ftp_file_name)
          handle = connection_obj.open!("#{self.directory}/#{ftp_file_name}")
          begin
            connection_obj.rename!("#{self.directory}/#{ftp_file_name}", "#{self.directory}/imported/#{new_file}")
          rescue Exception => e
            connection_obj.rename!("#{self.directory}/#{ftp_file_name}", "#{self.directory}/#{new_file}")
          end
          connection_obj.close!(handle)
        else
          result[:status] = false
          result[:error_messages].push('Error in updating file name in the ftp server')
          result[:error_messages].push(response[:error_messages])
        end
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push('Error in updating file name in the ftp server')
        result[:error_messages].push(e.message)
      end
      result
    end

    def upload_file(url, filename)
      result = self.build_result
      begin
        response = connect
        on_demand_logger = Logger.new("#{Rails.root}/log/ftp_export_upload.log")
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          begin
            data = Net::HTTP.get(URI.parse(url)) rescue nil
            File.open(filename, 'wb') {|f| f.write(data) }
            connection_obj.upload!(File.open(filename), "#{self.directory}/#{filename}")
          rescue => e
            log = { tenant: Apartment::Tenant.current, data: self.as_json, error: e, time: Time.current.utc }
            on_demand_logger.info(log)
          end
        else
          result[:status] = false
          response[:error_messages].each do |message|
            result[:error_messages].push(message)
          end
          log = { tenant: Apartment::Tenant.current, data: self.as_json, error: result, time: Time.current.utc }
          on_demand_logger.info(log)
          return result
        end
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
        log = { tenant: Apartment::Tenant.current, data: self.as_json, error: result, time: Time.current.utc }
        on_demand_logger.info(log)
      end
      result
    end

    def download_imported(current_tenant)
      result = self.build_result
      result[:file_info] = {}
      result[:file_info][:file_path] = ''
      result[:file_info][:ftp_file_name] = ''
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          system 'mkdir', '-p', "ftp_files/#{current_tenant}/verification"

          file_name = nil
          file_path = nil

          file = find_imported_file(connection_obj)

          unless file.nil?
            file_name = "#{Time.current.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
            handle = connection_obj.open!("#{self.directory}/imported/#{file}")
            connection_obj.download!("#{self.directory}/imported/#{file}", "ftp_files/#{current_tenant}/verification/#{file_name}")
            connection_obj.close!(handle)

            file_path = "#{Rails.root}/ftp_files/#{current_tenant}/verification/#{file_name}"
            result[:file_info][:file_path] = file_path
            result[:file_info][:ftp_file_name] = file
          else
            result[:status] = false
            result[:error_messages].push("All CSV files on the server appears to be verified.")
          end
        else
          result[:status] = false
          response[:error_messages].each do |message|
            result[:error_messages].push(message)
          end
          return result
        end
      rescue Net::SFTP::StatusException
        result[:status] = false
        result[:error_messages].push("All CSV files on the server appears to be verified.")
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def update_verified_status(ftp_file_name, verified = true)
      return

      result = self.build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          if verified
            new_file = rename_file(ftp_file_name, '-v')
            handle = connection_obj.open!("#{self.directory}/imported/#{ftp_file_name}")
            connection_obj.rename!("#{self.directory}/imported/#{ftp_file_name}", "#{self.directory}/imported/#{new_file}")
            connection_obj.close!(handle)
          else
            new_file = ftp_file_name.gsub('-imported', '')
            handle = connection_obj.open!("#{self.directory}/imported/#{ftp_file_name}")
            connection_obj.rename!("#{self.directory}/imported/#{ftp_file_name}", "#{self.directory}/#{new_file}")
            connection_obj.close!(handle)
          end
        else
          result[:status] = false
          result[:error_messages].push('Error in updating file name in the ftp server')
          result[:error_messages].push(response[:error_messages])
        end
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push('Error in updating file name in the ftp server')
        result[:error_messages].push(e.message)
      end
      result
    end

    private

    def find_file(connection_obj)
    	file = nil
      files = connection_obj.dir.glob(self.directory, "*.csv") + connection_obj.dir.glob(self.directory, "*.CSV")
    	files = files.sort_by { |f| f.attributes.mtime }
      files.each do |individual_file|
        unless '-imported'.in? individual_file.name
          file = individual_file.name
          break
        end
      end
      return file
    end

    def find_folder(connection_obj)
      folder_found = true
      begin
        found = connection_obj.dir.glob(self.directory, "imported")
        if found.any?
          folder_found = true
        else
          folder_found = false
        end
      rescue Exception => e
        folder_found = false
      end
      if folder_found == true
        return true
      else
        begin
          connection_obj.mkdir("#{self.directory}/imported", :permissions => 0755).wait
          return true
        rescue Exception => e
          return false
        end
      end
    end

    def find_imported_file(connection_obj)
      file = nil
      files = connection_obj.dir.glob(self.directory + '/imported', "*.csv") + connection_obj.dir.glob(self.directory + '/imported', "*.CSV")
      files = files.sort_by { |f| f.attributes.mtime }
      files.each do |individual_file|
        unless '-imported-v'.in? individual_file.name
          file = individual_file.name
          break
        end
      end
      file
    end
  end
end
