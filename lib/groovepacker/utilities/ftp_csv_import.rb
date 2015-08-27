class FTPCsvImport
  require ('net/sftp')

  def self.establish_connection
    # @host='45.55.84.212'
    # @username='deployer'
    # @password='dsodevtest!'
    @directory='csv/'
    begin
      credentials = FtpCredential.first unless FtpCredential.first.nil?
      unless credentials.nil?
        sftp = Net::SFTP.start(credentials.host, credentials.username, :password => credentials.password)
        return sftp
      else
        @result['status'] = false
        @result['error_messages'].push("FTP Credentials are required")
      end
    rescue Exception => e
      puts "establish_connection....................."
      @result['status'] = false
      @result['error_messages'].push(e.message)
    end
  end

  def self.retrieve_csv_file
    @result = {}
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['downloaded_file'] = {}
    begin
      sftp = self.establish_connection
      if @result['error_messages'].empty?
        # puts "sftp: " + sftp.inspect
        files = sftp.dir.glob(@directory, "*.csv").sort {|f| File.mtime(f)}
        files.each do |individual_file|
          unless '-imported'.in? individual_file.name
            @file = individual_file.name
            puts "file: " + @file
            break
          else
            next
          end
        end
        puts "file:"
        puts @file
        sftp.download!("#{@directory}/#{@file}", 'public/local.csv')
        puts ":::::::::::"
        @result['success_messages'].push("Connection succeeded! #{@file} was found.")
        downloaded_files = Dir.glob("#{Rails.root}/public/local.csv")
        downloaded_file = downloaded_files.first
        @result['downloaded_file'] = downloaded_file
      else
        puts "in else"
        return @result
      end
    rescue Exception => e
      puts "in rescue"
      puts e.message
      @result['status'] = false
      @result['error_messages'].push(e.message)
    end
    @result
  end

  def self.update_csv_file
    @result = {}
    @result['status'] = true
    begin
      sftp = self.establish_connection
      if @result['error_messages'].empty?
        sftp = Net::SFTP.start(@host, @username, :password => @password)
        files = sftp.dir.glob(@directory, "*.csv").sort {|f| File.mtime(f)}
        files.each do |individual_file|
          unless '-imported'.in? individual_file.name
            file = individual_file.name
            break
          else
            next
          end
        end
        puts "file: " + file
        new_file = ''
        new_file = rename_file(file,new_file)
        puts "new_file: " + new_file
        sftp.rename!(@directory+file, @directory+new_file)
      else
        return @result
      end
    rescue Exception => e
      puts e.message
      @result['status'] = false
      @result['error_messages'].push(e.message)
    end
    @result
  end

  def self.rename_file(file, new_file)
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
