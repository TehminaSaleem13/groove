class ImportCsv
  include AhoyEvent
  def import(tenant, params)
    result = {}
    result[:messages] = []
    result[:status] = true
    begin
      Apartment::Tenant.switch(tenant)
      params = eval(params)
      # track_user(tenant, params, "Import Started", "#{params[:type].capitalize} Import Started")
      # download CSV and save
      track_user(tenant, params, 'Import Started', "#{params[:type].capitalize} Import Started")
      response = nil
      file_path = nil
      store = Store.find(params[:store_id])
      credential = store.ftp_credential
      encoding_options = {
        invalid: :replace, # Replace invalid byte sequences
        undef: :replace, # Replace anything not defined in ASCII
        replace: '', # Use a blank for those replacements
        universal_newline: true # Always break lines with \n
      }
      if params[:flag] == 'ftp_download'
        ftp_type = params[:type] == 'product' ? 'product' : nil
        groove_ftp = FTP::FtpConnectionManager.get_instance(store, ftp_type)
        response = groove_ftp.download(tenant)
        if response[:status]
          file_path = response[:file_info][:file_path]
          if params[:encoding_format].present?
            begin
              file_content = File.read(file_path)
              regex = /(?<=\s)("[^"]+")(?=\s)/
              begin
                file_content[regex] = file_content[regex][1..-2]
              rescue
                nil
              end
              if params[:encoding_format] == "ASCII + UTF-8"
                new_file_data = file_content.encode(Encoding.find('ASCII'), encoding_options).encode("UTF-8")
              elsif params[:encoding_format] == "ISO-8859-1 + UTF-8"
                new_file_data = file_content.force_encoding("ISO-8859-1").encode("UTF-8")
              elsif params[:encoding_format] == "UTF-8"
                new_file_data = file_content.force_encoding("UTF-8")
              end
            rescue Exception => e
              new_file_data = file_content.encode(Encoding.find('ASCII'), encoding_options).encode("UTF-8")
            end
          else
            new_file_data =  File.read(file_path).encode(Encoding.find('ASCII'), encoding_options).encode("UTF-8")
          end  

          File.write(file_path,new_file_data)
          if Apartment::Tenant.current == "unitedmedco"
            first_remove = new_file_data.gsub(/\"\"/,"\"")
            second_remove = first_remove.gsub(/\"\"/,"\"")
            File.write(file_path, second_remove) 
          end 
          csv_file = begin
                      File.read(file_path).encode(Encoding.find('ASCII'), encoding_options)
                     rescue
                       nil
                     end if !store.csv_beta && params[:type] != "product"

          csv_file = File.read(file_path).encode(Encoding.find('ASCII'), encoding_options) rescue nil if params[:type] == "product"

          set_file_name(params, response[:file_info][:ftp_file_name])
          set_file_path(params, file_path)
        else
          result[:status] = false
          result[:messages].push(response[:error_messages])
        end
      else
        file = GroovS3.find_csv(tenant, params[:type], params[:store_id])
        set_file_name(params,file.url)
        file_path = download_csv(file,tenant, params)
        if params[:encoding_format].present?
          begin
            file_content = file.content
            regex = /(?<=\s)("[^"]+")(?=\s)/
            begin
              file_content[regex] = file_content[regex][1..-2]
            rescue
              nil
            end
            if params[:encoding_format] == "ASCII + UTF-8"
              File.write(file_path, file_content.encode(Encoding.find('ASCII'), encoding_options))
            elsif params[:encoding_format] == "ISO-8859-1 + UTF-8"
              File.write(file_path, file_content.force_encoding("ISO-8859-1").encode("UTF-8"))
            elsif params[:encoding_format] == "UTF-8"
              File.write(file_path, file_content.force_encoding("UTF-8"))
            end
          rescue Exception => e
            File.write(file_path, file.content.encode(Encoding.find('ASCII'), encoding_options))
          end
        else
          File.write(file_path, file.content.encode(Encoding.find('ASCII'), encoding_options))
        end       
        if Apartment::Tenant.current == "unitedmedco"
          first_remove = file.content.gsub(/\"\"/,"\"")
          second_remove = first_remove.gsub(/\"\"/,"\"")
          File.write(file_path, second_remove) 
        end 

        csv_file = begin
                    file.content.encode(Encoding.find('ASCII'), encoding_options)
                   rescue
                     nil
                   end if !(store.csv_beta && params[:type] == "order") 
        
        if check_mapping_for_tracking_num(params)
          csv_file = file.content.encode(Encoding.find('ASCII'), encoding_options) 
          params.merge!(only_for_tracking_num: true)
        end

        set_file_path(params, file_path)
      end
      set_data_for_csv_import_count(params[:file_path]) if params[:file_path]
      $redis.set("#{Apartment::Tenant.current}_csv_filename", params[:file_name])
      $redis.expire("#{Apartment::Tenant.current}_csv_filename", 18000)
      if csv_file.nil? && !store.csv_beta || file_path.blank? 
        result[:status] = false
        result[:messages].push("No file present to import #{params[:type]}") if result[:messages].empty?
      else
        if store.csv_beta && params[:type] == "order" && !csv_file
          begin
            ElixirApi::Processor::CSV::OrdersToXML.call('tenant' => tenant,'params' => params)
          rescue Net::ReadTimeout
            nil
          end
          Groovepacker::Orders::BulkActions.new.delay.update_bulk_orders_status({}, {}, Apartment::Tenant.current)
        else
          final_record = []
          if params[:fix_width] == 1
            if params[:flag] == 'ftp_download'
              initial_split = csv_file.split(/\n/).reject(&:empty?)
            else
              initial_split = csv_file.content.split(/\n/).reject(&:empty?)
            end
            initial_split.each do |single|
              final_record.push(single.scan(/.{1,#{params[:fixed_width]}}/m))
            end
          else
            require 'csv'
            params[:sep] = params[:sep] == '\\t' ? "\t" : params[:sep]
            final_record = begin
                              CSV.parse(csv_file, col_sep: params[:sep], quote_char: params[:delimiter], encoding: 'windows-1251:utf-8')
                            rescue
                              begin
                                CSV.parse(csv_file, col_sep: params[:sep], quote_char: '|', encoding: 'windows-1251:utf-8')
                              rescue
                                []
                              end
                            end
          end
          if params[:rows].to_i && params[:rows].to_i > 1
            final_record.shift(params[:rows].to_i - 1)
          end
          delete_index = 0
          params[:map].each_with_object({}) do |map_out|
            map_single_first_name = map_out[1].present? && map_out[1]['name']
            params[:map].delete(delete_index.to_s) if map_single_first_name == 'Unmapped'  
            delete_index += 1
          end
         
          mapping = {}
          params[:map].each do |map_single|
            next unless map_single[1].present? && map_single[1]['value'] != 'none'
            mapping[map_single[1]['value']] = {}
            mapping[map_single[1]['value']][:position] = map_single[0].to_i
            if map_single[1][:action].nil?
              mapping[map_single[1]['value']][:action] = 'skip'
            else
              mapping[map_single[1]['value']][:action] = map_single[1][:action]
            end
          end

          set_file_size(params, final_record)
          if params[:type] == 'order'
            import_order = Groovepacker::Stores::Importers::CSV::OrdersImporter.new(params, final_record, mapping, nil)
            result = import_order.import
            # result = Groovepacker::Stores::Importers::CSV::OrdersImporter.new.import(params,final_record,mapping)
          elsif params[:type] == 'product'
            # result = Groovepacker::Stores::Importers::CSV::ProductsImporter.new.import_old(params,final_record,mapping)
            import_product = Groovepacker::Stores::Importers::CSV::ProductsImporter.new(params, final_record, mapping, params[:import_action])
            result = import_product.import
          elsif params[:type] == 'kit'
            import_kit = Groovepacker::Stores::Importers::CSV::KitsImporter.new(params, final_record, mapping, params[:bulk_action_id])
            result = import_kit.import
          end
          # File.delete(file_path)
          if params[:flag] == 'ftp_download' && result[:add_imported]
            rename_ftp_file(store, result, response, params[:type])
            ftp_csv_import = Groovepacker::Orders::Import.new
            params[:type] == 'product' ? Groovepacker::Products::Products.new.ftp_product_import(Apartment::Tenant.current) : ftp_csv_import.ftp_order_import(Apartment::Tenant.current)
            begin
              File.delete(file_path)
            rescue
              nil
            end
          end
        end
      end
    rescue Exception => e
      Rollbar.error(e, e.message)
    end
        track_user(tenant, params, 'Import Finished', "#{params[:type].capitalize} Import Finished")
    result
  end

  def rename_ftp_file(store, result, response, type)
    import_item = ImportItem.where(store_id: store.id).last
    return result if import_item && import_item.status == 'cancelled' && type != 'product'
    groove_ftp = FTP::FtpConnectionManager.get_instance(store, type)
    response = groove_ftp.update(response[:file_info][:ftp_file_name])
    unless response[:status]
      result[:status] = false
      result[:messages].push(response[:error_messages])
    end
    result
  end

  private

  def set_file_name(params, file_url)
    params[:file_name] = file_url.split('/').last
  end

  def set_file_path(params, file_path)
    params[:file_path] = file_path
  end

  def set_file_size(params, final_record)
    params[:file_size] = (final_record.join("\n").bytesize.to_f / 1024).round(4)
  end

  def download_csv(file, tenant, params)
    system 'mkdir', '-p', "csv_files/#{tenant}"
    file_path = nil
    file_path = "#{Rails.root}/csv_files/#{tenant}/#{params[:file_name]}"
  end

  def check_mapping_for_tracking_num(params)
    default_map = CsvMap.find_or_initialize_by_name("Tracking Number Update")
    default_map.update_attributes(kind: "order", name: "Tracking Number Update", custom: true, map: {:rows=>2, :sep=>",", :other_sep=>0, :delimiter=>"\"", :fix_width=>0, :fixed_width=>4, :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>true, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YYYY TIME", :day_month_sequence=>"MM/DD", :map=>{"0"=>{"name"=>"Order number", "value"=>"increment_id"}, "1"=>{"name"=>"Tracking Number", "value"=>"tracking_num"}}})
    
    mappings_for_tracking_num = ['increment_id', 'tracking_num']
    mappings = []
    params[:map].values.each { |mapping| mappings << mapping['value'] }
    (mappings.sort == mappings_for_tracking_num.sort) ? true : false
  end

  def set_data_for_csv_import_count file_path
    begin
      require 'csv'
      $redis.expire("#{Apartment::Tenant.current}_csv_array", 0)
      csv_text_data = File.read(file_path)
      begin
        csv = CSV.parse(csv_text_data, :headers => true)
      rescue Exception => e
        csv_text_data = csv_text_data.gsub( /["\"]/, '')
        csv = CSV.parse(csv_text_data, :headers => true)
      end
      column_number = $redis.get("#{Apartment::Tenant.current}_csv_file_increment_id_index").to_i

      order_numbers = []
      csv.each do |row|
        column_name = row.as_json[column_number][0]
        order_numbers << row[column_name].strip unless row[column_name].blank? 
      end
      $redis.sadd("#{Apartment::Tenant.current}_csv_array", order_numbers.uniq)
    rescue Exception => e
      Rollbar.error(e, e.message)
    end
  end
end
