module SettingsHelper
  def zip_to_files(filename,data_object)
    require 'zip'
    temp_file = Tempfile.new(filename)
    begin
      Zip::OutputStream.open(temp_file) { |zos| }
      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|
        data_object.each do |ident,file|
          zip.add(ident.to_s+".csv", file)
        end
      end
      zip_data = File.read(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
end
