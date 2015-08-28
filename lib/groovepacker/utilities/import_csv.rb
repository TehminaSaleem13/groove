class ImportCsv
  def import(tenant, params)
    result = {}
    result['messages'] = []
    begin
      Apartment::Tenant.switch(tenant)
      #download CSV and save
      if params[:flag] == 'ftp_download'
        csv_file = File.read(params[:file_path])
      else
        csv_file = GroovS3.find_csv(tenant, params[:type], params[:store_id])
      end
      if csv_file.nil?
        result['messages'].push("No file present to import #{params[:type]}")
      else
        #csv_directory = 'uploads/csv'
        #file_path = File.join(csv_directory, "#{tenant}.#{params[:store_id]}.#{params[:type]}.csv")
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
          if params[:flag] == 'ftp_download'
            CSV.parse(csv_file, :col_sep => params[:sep], :quote_char => params[:delimiter], :encoding => 'windows-1251:utf-8') do |single|
              final_record.push(single)
            end
          else
            CSV.parse(csv_file.content, :col_sep => params[:sep], :quote_char => params[:delimiter], :encoding => 'windows-1251:utf-8') do |single|
              final_record.push(single)
            end
          end
        end
        if params[:rows].to_i && params[:rows].to_i > 1
          final_record.shift(params[:rows].to_i - 1)
        end
        mapping = {}
        params[:map].each do |map_single|
          if map_single[1][:value] != 'none'
            mapping[map_single[1][:value]] = {}
            mapping[map_single[1][:value]][:position] = map_single[0].to_i
            if map_single[1][:action].nil?
              mapping[map_single[1][:value]][:action] = 'skip'
            else
              mapping[map_single[1][:value]][:action] = map_single[1][:action]
            end
          end
        end

        if params[:type] == 'order'
          result = Groovepacker::Stores::Importers::CSV::OrdersImporter.new.import_old(params, final_record, mapping)
          #result = Groovepacker::Stores::Importers::CSV::OrdersImporter.new.import(params,final_record,mapping)
        elsif params[:type] == 'product'
          #result = Groovepacker::Stores::Importers::CSV::ProductsImporter.new.import_old(params,final_record,mapping)
          result = Groovepacker::Stores::Importers::CSV::ProductsImporter.new.import(params, final_record, mapping, params[:import_action])
        elsif params[:type] == 'kit'
          result = Groovepacker::Stores::Importers::CSV::KitsImporter.new.import(params, final_record, mapping, params[:bulk_action_id])
        end
        #File.delete(file_path)

      end
    rescue Exception => e
      raise e
    end
    result
  end

end
