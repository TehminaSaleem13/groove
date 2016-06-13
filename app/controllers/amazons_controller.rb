class AmazonsController < ApplicationController
	def products_import
		@result = {'status' => true, 'messages' => []}
		@store = Store.find(params[:id])
		amazon_product_file_import
    respond_to do |format|
  		format.json { render json: @result }
		end
	end

	private
	def amazon_product_file_import
		if @store.id
	    @current_tenant = Apartment::Tenant.current
	    path = File.join("uploads/csv", "#{@current_tenant}.#{@store.id}.amazon_product.csv")
	    amazon_product_file_data = params[:productfile].read
	    @header = amazon_product_file_data.split("\n")[0].split("\t")
	    check_text_file_and_upload(amazon_product_file_data, path)
	  end
	end

	def check_text_file_and_upload(amazon_product_file_data, path)
		if (@header.include? "product-id" && "seller-sku" && "item-name") && File.extname(params["productfile"].original_filename) == ".txt"
	    File.open(path, "wb") { |f| f.write(amazon_product_file_data) }
	    GroovS3.create_csv(@current_tenant, 'amazon_product', @store.id, amazon_product_file_data, :public_read)
	    @result['csv_import'] = true
	    handler = Groovepacker::Stores::Handlers::AmazonHandler.new(@store)
	    context = Groovepacker::Stores::Context.new(handler)
	    context.delay(:run_at => 1.seconds.from_now).import_products
	    # context.import_products
	  else
	    @result['status'] = false
	   	@result['messages'] = "The provided file does not match the expected Amazon Active Listings Report format."
	  end
	end
end
