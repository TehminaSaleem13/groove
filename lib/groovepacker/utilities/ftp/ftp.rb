# frozen_string_literal: true

module FTP
  class FTP < FTPBase
    include ApplicationHelper
    require 'net/ftp'

    def connect
      result = build_result
      begin
        if host.nil? || username.nil? || password.nil?
          result[:status] = false
          result[:error_messages].push('FTP Credentials are required')
        else
          Timeout.timeout(20) do
            if host.include?(':')
              string = host.split(':')
              ftp = Net::FTP.new
              ftp.connect(string[0], string[1])
              ftp.login(username, password)
              ftp.passive = true
              result[:connection_obj] = ftp
            else
              result[:connection_obj] = Net::FTP.new(host, username, password)
              result[:connection_obj].passive = true
            end
          end
          return result
        end
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
      rescue Timeout::Error
        result[:status] = false
        result[:error_messages].push('Operation timedout.')
      rescue SocketError
        result[:status] = false
        result[:error_messages].push('Unknown server name')
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push('Error in connecting the server. Please check your credentails.')
      end
      result
    end

    def upload_file(url, filename)
      result = build_result
      begin
        response = connect
        on_demand_logger = Logger.new("#{Rails.root.join('log/ftp_export_upload.log')}")
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          connection_obj.chdir(directory)
          begin
            data = begin
              Net::HTTP.get(URI.parse(url))
            rescue StandardError
              nil
            end
            File.open(filename, 'wb') { |f| f.write(data) }
            connection_obj.putbinaryfile(File.open(filename))
          rescue StandardError => e
            log = { tenant: Apartment::Tenant.current, data: as_json, error: e, time: Time.current.utc }
            on_demand_logger.info(log)
          end
        else
          result[:status] = false
          response[:error_messages].each do |message|
            result[:error_messages].push(message)
          end
          log = { tenant: Apartment::Tenant.current, data: as_json, error: result, time: Time.current.utc }
          on_demand_logger.info(log)
          return result
        end
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
        log = { tenant: Apartment::Tenant.current, data: as_json, error: result, time: Time.current.utc }
        on_demand_logger.info(log)
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
        log = { tenant: Apartment::Tenant.current, data: as_json, error: result, time: Time.current.utc }
        on_demand_logger.info(log)
      end
      result
    end

    def download_imported(current_tenant)
      result = build_result
      result[:file_info] = {}
      result[:file_info][:file_path] = ''
      result[:file_info][:ftp_file_name] = ''
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          system 'mkdir', '-p', "ftp_files/#{current_tenant}/verification"

          file_name = nil
          file_path = nil
          found_file = find_file(connection_obj)

          if found_file.nil?
            result[:status] = false
            result[:error_messages].push('All CSV files on the server appears to be varified.')
          else
            file_name = "#{Time.current.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
            # connection_obj.chdir("~/#{self.directory}")
            connection_obj.getbinaryfile(found_file.to_s, "ftp_files/#{current_tenant}/verification/#{file_name}")

            file_path = "#{Rails.root.join("ftp_files/#{current_tenant}/verification#{file_name}")}"
            result[:file_info][:file_path] = file_path
            result[:file_info][:ftp_file_name] = found_file
            connection_obj.close
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
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def update_verified_status(ftp_file_name, verified = true)
      result = build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          if verified
            new_file = rename_file(ftp_file_name, '-v')
            connection_obj.rename("#{directory}/#{ftp_file_name}", "#{directory}/imported/#{new_file}")
          else
            new_file = ftp_file_name.gsub('-imported', '')
            connection_obj.rename("#{directory}/#{ftp_file_name}", "#{directory}/imported/#{new_file}")
          end
          connection_obj.close
        else
          result[:status] = false
          result[:error_messages].push('Error in updating file name in the ftp server')
          result[:error_messages].push(response[:error_messages])
        end
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push('Error in updating file name in the ftp server')
        result[:error_messages].push(e.message)
      end
      result
    end

    def retrieve
      result = build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          file = find_file(connection_obj)
          connection_obj.close
          if file.nil?
            result[:status] = false
            result[:error_messages].push('All CSV files on the server appear to have been imported.')
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
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def check_imported
      result = build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          folder = find_folder(connection_obj)
          connection_obj.close
          if folder == true
            result[:success_messages].push('Imported Folder Ready')
          else
            result[:status] = false
            result[:error_messages].push('Unable to create the imported folder in the current directory. Please create it manually.')
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
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def download(current_tenant)
      result = build_result
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

          if found_file.nil?
            result[:status] = false
            result[:error_messages].push('All CSV files on the server appear to have been imported.')
          else
            file_name = "#{Time.current.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
            # connection_obj.chdir("~/#{self.directory}")
            connection_obj.getbinaryfile(found_file.to_s, "ftp_files/#{current_tenant}/#{file_name}")

            file_path = "#{Rails.root.join("ftp_files/#{current_tenant}/#{file_name}")}"
            result[:file_info][:file_path] = file_path
            result[:file_info][:ftp_file_name] = found_file
            connection_obj.close
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
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push(e.message)
      end
      result
    end

    def update(ftp_file_name)
      result = build_result
      begin
        response = connect
        if response[:error_messages].empty? && response[:status] == true
          connection_obj = response[:connection_obj]
          new_file = rename_file(ftp_file_name)
          begin
            connection_obj.rename("#{directory}/#{ftp_file_name}", "#{directory}/imported/#{new_file}")
          rescue Exception => e
            connection_obj.rename("#{directory}/#{ftp_file_name}", "#{directory}/#{new_file}")
          end

          connection_obj.close
        else
          result[:status] = false
          result[:error_messages].push('Error in updating file name in the ftp server')
          result[:error_messages].push(response[:error_messages])
        end
      rescue Net::FTPPermError => e
        message = e.message
        split_message = message.split(' ')
        split_message.shift
        result[:status] = false
        result[:error_messages].push(split_message.join(' '))
      rescue Exception => e
        result[:status] = false
        result[:error_messages].push('Error in updating file name in the ftp server')
        result[:error_messages].push(e.message)
      end
      result
    end

    def delete_older_files
      result = build_result
      response = connect
      if response[:error_messages].empty? && response[:status] == true
        connection_obj = response[:connection_obj]
        connection_obj.chdir("/#{directory}/imported")
        connection_obj.nlst('*.csv') + connection_obj.nlst('*.CSV').each do |file|
          modified_time = connection_obj.mtime(file)
          connection_obj.delete("/#{directory}/imported/#{file}") if modified_time < 90.days.ago
        end
      else
        result[:status] = false
        response[:error_messages].each do |message|
          result[:error_messages].push(message)
        end
        result
      end
    end

    private

    def find_file(connection_obj)
      file = nil
      connection_obj.chdir(directory)
      files = begin
        connection_obj.nlst.select { |f| f.end_with?('.csv', '.CSV') }
      rescue StandardError
        []
      end
      files = files.sort_by { |filename| connection_obj.mtime(filename) }
      files.each do |individual_file|
        unless '-imported'.in? individual_file
          file = individual_file
          break
        end
      end
      file
    end

    def find_folder(connection_obj)
      folder_found = true
      begin
        connection_obj.chdir("#{directory}/imported")
        folder_found = true
      rescue Exception => e
        folder_found = false
      end
      return true if folder_found == true

      begin
        connection_obj.chdir(directory)
        connection_obj.mkdir('imported')
        true
      rescue Exception => e
        false
      end
    end

    def find_imported_file(connection_obj)
      file = nil
      connection_obj.chdir(directory)
      begin
        files = connection_obj.nlst('*.csv') + connection_obj.nlst('*.CSV')
      rescue StandardError
        files = begin
          connection_obj.nlst('*.csv')
        rescue StandardError
          connection_obj.nlst('*.CSV')
        end
      end
      files = files.sort_by { |filename| connection_obj.mtime(filename) }
      files.each do |individual_file|
        unless '-imported-v'.in? individual_file
          file = individual_file
          break
        end
      end
      file
    end
  end
end
