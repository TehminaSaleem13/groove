module FTP  
  class SFTP < FTPBase
    include ApplicationHelper
  	require ('net/sftp')

    def connect
      result = self.build_result
      begin
        unless self.host.nil? || self.username.nil? || self.password.nil?
          Timeout.timeout(10) do
            result[:connection_obj] = Net::SFTP.start(self.host, self.username, :password => self.password)
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
            result[:error_messages].push("No CSV files could be found without '-imported' in the file name")
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
            file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
            handle = connection_obj.open!("#{self.directory}/#{file}")
            connection_obj.download!("#{self.directory}/#{file}", "ftp_files/#{current_tenant}/#{file_name}")
            connection_obj.close!(handle)

            file_path = "#{Rails.root}/ftp_files/#{current_tenant}/#{file_name}"
            result[:file_info][:file_path] = file_path
            result[:file_info][:ftp_file_name] = file
          else
            result[:status] = false
            result[:error_messages].push("No CSV files could be found without '-imported' in the file name")
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
        result[:error_messages].push("No CSV files could be found without '-imported' in the file name")
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
          handle = connection_obj.open!("#{self.directory}/#{ftp_file_name}")
          connection_obj.rename!("#{self.directory}/#{ftp_file_name}", "#{self.directory}/#{new_file}")
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

    private

    def find_file(connection_obj)
    	file = nil
    	files = connection_obj.dir.glob(self.directory, "*.csv").sort_by {|f| f.attributes.mtime}.reverse
      files.each do |individual_file|
        unless '-imported'.in? individual_file.name
          file = individual_file.name
          break
        end
      end
      return file
    end
  end
end
