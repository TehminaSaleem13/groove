namespace :fci do
  desc "import csv file from server"

  task :retrieve_csv_and_import_orders => :environment do
    begin
      puts "starting the rake task..."
      FTPCsvImport.retrieve_csv_file
      import_csv = ImportCsv.new
      import_csv.import('groovepacks_development', {:type=>"order", :fix_width=>0, :fixed_width=>4, :sep=>",", :delimiter=>"\"", :rows=>2, :map=>{"0"=>{"name"=>"Order Date/Time", "value"=>"order_placed_time"}, "1"=>{"name"=>"Category Name", "value"=>"category"}, "2"=>{"name"=>"Order number", "value"=>"increment_id"}, "3"=>{"name"=>"(First) Name", "value"=>"firstname"}, "4"=>{"name"=>"Address 1", "value"=>"address_1"}, "5"=>{"name"=>"Postal Code", "value"=>"postcode"}, "6"=>{"name"=>"SKU", "value"=>"sku"}, "7"=>{"name"=>"Product Name", "value"=>"product_name"}, "8"=>{"name"=>"Product Instructions", "value"=>"product_instructions"}, "9"=>{"name"=>"Quantity", "value"=>"qty"}, "10"=>{"name"=>"Image URL", "value"=>"image"}}, :store_id=>18, :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_placed_at=>nil, :order_date_time_format=>"MM/DD/YYYY TIME", :day_month_sequence=>"DD/MM"})
      puts "completed import"
      FTPCsvImport.update_csv_file
      puts "updation complete"
    rescue Exception => e
      puts e.message
    end
  end
end
