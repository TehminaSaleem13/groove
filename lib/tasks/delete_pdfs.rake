namespace :db do
  desc "delete all files created before certain time"
  task :delete_pdfs => :environment do
  	@files = []
  	Dir.chdir('public')
    Dir.chdir('pdfs')
    dir = Dir.pwd
  	Dir.entries(dir).each do |f|
      p f
      if f !='.' && f != '..'
    		full_filename = File.join( Dir.pwd , f)
    		stat = File::Stat.new( full_filename )
        seconds_diff = (Time.now - stat.ctime).to_i.abs
        minutes = seconds_diff / 60
        if minutes > 1
        	@files << full_filename
        end
      end
  	end
    @files.each do |file|
    	File.delete(file)
    end
  end
end