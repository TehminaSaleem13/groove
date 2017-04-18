namespace :doo do
  desc "Update Barcode Qty"
  task :update_barcode_qty => :environment do
    tenants = Tenant.order(:name) rescue Tenant.all
    tenants.each do |tenant|
    	begin
	    	Apartment::Tenant.switch tenant.name
	        ProductBarcode.all.each do |pro|
				pro.is_multipack_barcode = true
				pro.packing_count = 1 if pro.packing_count.blank?
				pro.save
			end
		rescue
		end
    end
    exit(1)
  end
end
