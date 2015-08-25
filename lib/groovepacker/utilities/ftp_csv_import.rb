class FTPCsvImport
  require ('net/sftp')

  def self.retrieve_csv_file
    # @host = '45.55.84.212'
    # @user_name = 'deployer'
    # @password = 'dsodevtest!'
    # @port = 21
    # @directory = 'csv/'
    # login_to_ftp_server
    # files = @sftp.chdir(@directory)
    sftp = Net::SFTP.start('45.55.84.212', 'deployer', :password => 'dsodevtest!')
    files = sftp.dir.glob('csv/', "*.csv").sort {|f| File.mtime(f)}
    file = files.first.name
    sftp.download!('csv/'+file, 'public/local.csv')
    # @sftp.close
  end

  def self.update_csv_file
    # login_to_ftp_server
    # files = @ftp.chdir(@directory)
    # @file = @ftp.glob("*.csv").max_by {|f| File.mtime(f)}
    # @ftp.puttextfile('public/local.csv', @file)
    sftp = Net::SFTP.start('45.55.84.212', 'deployer', :password => 'dsodevtest!')
    files = sftp.dir.glob('csv/', "*.csv").sort {|f| File.mtime(f)}
    file = files.first.name
    new_file = ''
    new_file = rename_file(file,new_file)
    puts "new_file: " + new_file
    sftp.rename('csv/'+file, 'csv/'+new_file)
    # @ftp.close
  end

  # def self.login_to_ftp_server
    # require ('net/sftp')
    # require 'net/ftp'
    # @ftp = Net::FTP.new(@host, @user_name, @password)
    # @ftp.login
    

    # @sftp = Net::SFTP.start('45.55.84.212', 'deployer', :password => 'dsodevtest!')

  # end

  def self.rename_file(file, new_file)
    substrings = file.split('.')
    substrings.each do |value|
      if(value == substrings[-1])
        new_file+=('.'+value)
      elsif(value == substrings[-2])
        new_file+=(value+'_modified')
      else
        new_file+=value
      end
    end
    new_file
  end
end
