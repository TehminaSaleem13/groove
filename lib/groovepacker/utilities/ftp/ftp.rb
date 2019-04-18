module FTP
  class FTP < FTPBase
    include ApplicationHelper
    require ('net/ftp')

    def connect
      result = self.build_result
      begin
        unless self.host.nil? || self.username.nil? || self.password.nil?
          Timeout.timeout(20) do
            if self.host.include?(":")
              string = self.host.split(":") 
              ftp = Net::FTP.new
              ftp.connect(string[0], string[1])
              ftp.login(self.username, self.password)
              ftp.passive = true
              result[:connection_obj] = ftp
            else 
              result[:connection_obj] = Net::FTP.new(self.host, self.username, self.password)
              result[:connection_obj].passive = true
            end
          end
          return result
        else
          result[:status] = false
          result[:error_messages].push("FTP Credentials are required")
        end
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(" ")
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(" "))
      rescue Timeout::Error
        result[:status] = false
        result[:error_messages].push("Operation timedout.")
      rescue SocketError
        result[:status] = false
        result[:error_messages].push("Unknown server name")
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
          connection_obj.close()
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
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(" ")
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(" "))
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
          connection_obj.close()
          if folder == true
            result[:status] = false
            result[:error_messages].push("Impoted folder Found")
          else
            result[:success_messages].push("Does not have permission to create folder")
          end
        else
          result[:status] = false
          response[:error_messages].each do |message|
            result[:error_messages].push(message)
          end
          return result
        end
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(" ")
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(" "))
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
          found_file = find_file(connection_obj)
          
          unless found_file.nil?
            file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
            # connection_obj.chdir("~/#{self.directory}")
            connection_obj.getbinaryfile("#{found_file}", "ftp_files/#{current_tenant}/#{file_name}")
            
            file_path = "#{Rails.root}/ftp_files/#{current_tenant}/#{file_name}"
            result[:file_info][:file_path] = file_path
            result[:file_info][:ftp_file_name] = found_file
            connection_obj.close()
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
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(" ")
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(" "))
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def update(ftp_file_name)
      result = self.build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          new_file = rename_file(ftp_file_name)
          begin
            connection_obj.rename("#{self.directory}/#{ftp_file_name}", "#{self.directory}/imported/#{new_file}")
          rescue Exception => e
            connection_obj.rename("#{self.directory}/#{ftp_file_name}", "#{self.directory}/#{new_file}")
          end
          
          connection_obj.close()
        else
          result[:status] = false
          result[:error_messages].push('Error in updating file name in the ftp server')
          result[:error_messages].push(response[:error_messages])
        end
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(" ")
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(" "))
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
    	connection_obj.chdir(self.directory)
      begin
        files = connection_obj.nlst('*.csv') + connection_obj.nlst('*.CSV')
      rescue
        files = connection_obj.nlst('*.csv') rescue connection_obj.nlst('*.CSV')
      end
      files.each do |individual_file|
        unless '-imported'.in? individual_file
          file = individual_file
          break
        end
      end
      return file
    end

    def find_folder(connection_obj)
      folder_found = true
      begin
        connection_obj.chdir("#{self.directory}/imported")
        folder_found = true
      rescue Exception => e
        folder_found = false
      end
      if folder_found == true
        return true
      else
        begin
          connection_obj.chdir(self.directory)
          connection_obj.mkdir("imported")
          return true
        rescue Exception => e
          return false
        end
      end
    end
  end
end
