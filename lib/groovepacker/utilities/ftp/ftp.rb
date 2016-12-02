module FTP
  class FTP < FTPBase
    include ApplicationHelper
    require ('net/ftp')

    def connect
      result = self.build_result
      begin
        unless self.host.nil? || self.username.nil? || self.password.nil?
          Timeout.timeout(20) do
            result[:connection_obj] = Net::FTP.new(self.host, self.username, self.password)
            result[:connection_obj].passive = true
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
          
          connection_obj.rename("#{self.directory}/#{ftp_file_name}", "#{self.directory}/#{new_file}")
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
    	connection_obj.chdir(self.directory)
      files = connection_obj.nlst('*.csv')
      fmtimes = []
      files.each do |individual_file|
        if '-imported'.in? individual_file
          fmtimes << Time.now.utc-1.year
        else
          fmtimes << connection_obj.mtime(individual_file)
        end
      end
      unless fmtimes.index(fmtimes.max).nil? || ('-imported'.in? files[fmtimes.index(fmtimes.max)])
        index = fmtimes.index(fmtimes.max)
        files[index]
      end
    end
  end
end
