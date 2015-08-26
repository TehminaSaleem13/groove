class FTPCsvImport
  require ('net/sftp')

  def self.retrieve_csv_file
    @host='45.55.84.212'
    @username='deployer'
    @password='dsodevtest!'
    @directory='csv/'
    begin
      sftp = Net::SFTP.start(@host, @username, :password => @password)
      files = sftp.dir.glob(@directory, "*.csv").sort {|f| File.mtime(f)}
      file = files.first.name
      sftp.download!(@directory+file, 'public/local.csv')
    rescue Exception => e
      puts e.message
    end
  end

  def self.update_csv_file
    begin
      sftp = Net::SFTP.start(@host, @username, :password => @password)
      files = sftp.dir.glob(@directory, "*.csv").sort {|f| File.mtime(f)}
      file = files.first.name
      puts "file: " + file
      new_file = ''
      new_file = rename_file(file,new_file)
      puts "new_file: " + new_file
      sftp.rename!(@directory+file, @directory+new_file)
    rescue Exception => e
      puts e.message
    end
  end

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
