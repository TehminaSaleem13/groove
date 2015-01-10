class ImportCsv
  def import(tenant,params)
    begin
      Apartment::Tenant.switch(tenant)
      csv_directory = 'uploads/csv'
      file_path = File.join(csv_directory, "#{tenant}.#{params[:store_id]}.#{params[:type]}.csv")
      if File.exists? file_path
        final_record = []
        if params[:fix_width] == 1
          initial_split = IO.readlines(file_path)
          initial_split.each do |single|
            final_record.push(single.scan(/.{1,#{params[:fixed_width]}}/m))
          end
        else
          require 'csv'
          CSV.foreach(file_path,:col_sep => params[:sep], :quote_char => params[:delimiter] ,:encoding => 'windows-1251:utf-8') do |single|
            final_record.push(single)
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
          result = Groovepacker::Store::Importers::CSV::OrdersImporter.new.import_old(params,final_record,mapping)
          #result = Groovepacker::Store::Importers::CSV::OrdersImporter.new.import(params,final_record,mapping)
        else
          #result = Groovepacker::Store::Importers::CSV::ProductsImporter.new.import_old(params,final_record,mapping)
          result = Groovepacker::Store::Importers::CSV::ProductsImporter.new.import(params,final_record,mapping)
        end
        File.delete(file_path)
      else
        result['messages'].push("No file present to import #{params[:type]}")
      end
    rescue Exception => e
      raise e
    end
  end

end
