class GroovFTP
  require ('net/sftp')
  attr_accessor :directory, :host

  def establish_connection(store_id)
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['connection_obj'] = nil
    begin
      credentials = FtpCredential.where(:store_id => store_id) unless FtpCredential.where(:store_id => store_id).empty?
      unless credentials.empty?
        credential = credentials.first
        split_location = credential.host.split('/')
        self.host = split_location.first
        self.directory = split_location.last
        result['connection_obj'] = Net::SFTP.start(self.host, credential.username, :password => credential.password)
        return result
      else
        result['status'] = false
        result['error_messages'].push("FTP Credentials are required")
      end
    rescue Exception => e
      result['status'] = false
      result['error_messages'].push(e.message)
    end
    result
  end

  def retrieve(store_id)
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    begin
      response = self.establish_connection(store_id)
      if response['error_messages'].empty? && response['status'] == true
        sftp = response['connection_obj']
        file = nil
        files = sftp.dir.glob(self.directory, "*.csv").sort_by {|f| f.attributes.mtime}.reverse
        files.each do |individual_file|
          unless '-imported'.in? individual_file.name
            file = individual_file.name
            break
          end
        end
        if file.nil?
          result['status'] = false
          result['error_messages'].push("No CSV files could be found without '-imported' in the file name")
        else
          result['success_messages'].push("Connection succeeded! #{file} was found.")
        end
      else
        result['error_messages'].push(response['error_messages'])
        return result
      end
    rescue Exception => e
      result['status'] = false
      result['error_messages'].push(e.message)
    end
    result
  end

  def download(store_id, current_tenant)
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['file_info'] = {}
    result['file_info']['file_path'] = ''
    result['file_info']['ftp_file_name'] = ''
    begin
      response = self.establish_connection(store_id)
      if response['error_messages'].empty? && response['status'] == true
        sftp = response['connection_obj']
        system 'mkdir', '-p', "ftp_files/#{current_tenant}"
        found_file = nil
        file_name = nil
        file_path = nil
        files = sftp.dir.glob(self.directory, "*.csv").sort_by {|f| f.attributes.mtime}.reverse
        files.each do |individual_file|
          unless '-imported'.in? individual_file.name
            found_file = individual_file.name
            break
          end
        end
        unless found_file.nil?
          file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
          sftp.download!("#{self.directory}/#{found_file}", "ftp_files/#{current_tenant}/#{file_name}")
          file_path = "#{Rails.root}/ftp_files/#{current_tenant}/#{file_name}"
          result['file_info']['file_path'] = file_path
          result['file_info']['ftp_file_name'] = found_file
        else
          result['status'] = false
          result['error_messages'].push("No CSV files could be found without '-imported' in the file name")
        end
      else
        return result
      end
    rescue Exception => e
      result['status'] = false
      result['error_messages'].push(e.message)
    end
    result
  end

  def update(store_id,ftp_file_name)
    result = {}
    result['status'] = true
    result['error_messages'] = []
    begin
      response = self.establish_connection(store_id)
      if response['error_messages'].empty? && response['status'] == true
        sftp = response['connection_obj']
        new_file = ''
        new_file = rename_file(ftp_file_name,new_file)
        sftp.rename!("#{self.directory}/#{ftp_file_name}", "#{self.directory}/#{new_file}")
      else
        result['status'] = false
        result['error_messages'].push('Error in updating file name in the ftp server')
        result['error_messages'].push(response['error_messages'])
      end
    rescue Exception => e
      result['status'] = false
      result['error_messages'].push('Error in updating file name in the ftp server')
      result['error_messages'].push(e.message)
    end
    result
  end

  def rename_file(file, new_file)
    substrings = file.split('.')
    substrings.each do |value|
      if(value == substrings[-1])
        new_file+=('.'+value)
      elsif(value == substrings[-2])
        new_file+=(value+'-imported')
      else
        new_file+=value
      end
    end
    new_file
  end
end
