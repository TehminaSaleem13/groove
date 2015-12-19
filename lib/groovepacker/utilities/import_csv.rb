class ImportCsv
  def import(tenant, params)
    result = {}
    result[:messages] = []
    result[:status] = true
    begin
      Apartment::Tenant.switch(tenant)
      params = eval(params)
      #download CSV and save
      response = nil
      file_path = nil
      store = Store.find(params[:store_id])
      credential = store.ftp_credential
      encoding_options = {
        :invalid           => :replace,  # Replace invalid byte sequences
        :undef             => :replace,  # Replace anything not defined in ASCII
        :replace           => '',        # Use a blank for those replacements
        :universal_newline => true       # Always break lines with \n
      }
      if params[:flag] == 'ftp_download'
        groove_ftp = FTP::FtpConnectionManager.get_instance(store)
        response = groove_ftp.download(tenant)
        if response[:status]
          file_path = response[:file_info][:file_path]
          csv_file = File.read(file_path).encode(Encoding.find('ASCII'), encoding_options)
        else
          result[:status] = false
          result[:messages].push(response[:error_messages])
        end
      else
        file = GroovS3.find_csv(tenant, params[:type], params[:store_id])
        csv_file = file.content.encode(Encoding.find('ASCII'), encoding_options)
      end
      if csv_file.nil?
        result[:status] = false
        result[:messages].push("No file present to import #{params[:type]}") if result[:messages].empty?
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
          CSV.parse(csv_file, :col_sep => params[:sep], :quote_char => params[:delimiter], :encoding => 'windows-1251:utf-8') do |single|
            final_record.push(single)
          end
        end
        if params[:rows].to_i && params[:rows].to_i > 1
          final_record.shift(params[:rows].to_i - 1)
        end
        mapping = {}
        params[:map].each do |map_single|
          if map_single[1]['value'] != 'none'
            mapping[map_single[1]['value']] = {}
            mapping[map_single[1]['value']][:position] = map_single[0].to_i
            if map_single[1][:action].nil?
              mapping[map_single[1]['value']][:action] = 'skip'
            else
              mapping[map_single[1]['value']][:action] = map_single[1][:action]
            end
          end
        end

        if params[:type] == 'order'
          import_order = Groovepacker::Stores::Importers::CSV::OrdersImporter.new(params, final_record, mapping, nil)
          result = import_order.import()
          #result = Groovepacker::Stores::Importers::CSV::OrdersImporter.new.import(params,final_record,mapping)
        elsif params[:type] == 'product'
          #result = Groovepacker::Stores::Importers::CSV::ProductsImporter.new.import_old(params,final_record,mapping)
          import_product = Groovepacker::Stores::Importers::CSV::ProductsImporter.new(params, final_record, mapping, params[:import_action])
          result = import_product.import()
        elsif params[:type] == 'kit'
          import_kit = Groovepacker::Stores::Importers::CSV::KitsImporter.new(params, final_record, mapping, params[:bulk_action_id])
          result = import_kit.import()
        end
        #File.delete(file_path)
        if params[:flag] == 'ftp_download'
          groove_ftp = FTP::FtpConnectionManager.get_instance(store)
          response = groove_ftp.update(response[:file_info][:ftp_file_name])
          unless response[:status]
            result[:status] = false
            result[:messages].push(response[:error_messages])
          end
          File.delete(file_path)
        end
      end
    rescue Exception => e
      raise e
    end
    result
  end
end
