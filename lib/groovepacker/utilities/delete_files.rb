class DeleteFiles

  def self.delete_files
    @files = []
    Dir.chdir('public')
    Dir.chdir('pdfs')
    dir = Dir.pwd
    get_all_files(dir).each do |file|
      @files << file
    end
    Dir.chdir('..')
    Dir.chdir('csv')
    dir = Dir.pwd
    get_all_files(dir).each do |file|
      @files << file
    end
    @files.each do |file|
      File.delete(file)
    end
    Dir.chdir(Rails.root)
    #DeleteFiles.delay(:run_at => 20.seconds.from_now).delete_pdfs
  end

  def self.get_all_files(dir)
    files = []
    Dir.entries(dir).each do |f|
      p f
      if f !='.' && f != '..' && f != '.gitignore'
        full_filename = File.join(Dir.pwd, f)
        stat = File::Stat.new(full_filename)
        seconds_diff = (Time.now - stat.ctime).to_i.abs
        minutes = seconds_diff / 60
        if minutes > 1
          files << full_filename
        end
      end
    end
    files
  end

end
