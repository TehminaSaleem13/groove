class ImportOrders
	def import_orders
		# @result = Hash.new
		# we will remove all the jobs pertaining to import which are not started

		# order_import_summaries = OrderImportSummary.where(status: 'not started')
		# if !order_import_summaries.empty?
		# 	order_import_summary = order_import_summaries.first

		# 	puts "order_import_summary:"+order_import_summary.inspect
		# 	order_import_summary.status = 'in progress'
		# 	order_import_summary.save
		# end

		# we will also remove all the import summary which are not started.
		order_import_summaries = OrderImportSummary.where(status: ['not started','completed'])
		if !order_import_summaries.empty?
			order_import_summaries.each do |order_import_summary|
				if order_import_summary == order_import_summaries.first
					order_import_summary.status = 'in progress'
					order_import_summary.save
				end
				if order_import_summary.status != 'in progress'
					order_import_summary.delete
				end
			end
		end

		stores = Store.where("status = '1' AND store_type != 'system'")
		if stores.length != 0	
			stores.each do |store|
				if store.store_type == 'Amazon'
      		# context = Groovepacker::Store::Context.new(
        #  	Groovepacker::Store::Handlers::AmazonHandler.new(store))
       	# 	result = context.import_orders
       	# 	puts result.inspect
     		elsif store.store_type == 'Ebay1'
       		context = Groovepacker::Store::Context.new(
         	Groovepacker::Store::Handlers::EbayHandler.new(store))
       		puts context.import_orders.inspect
     		end
				# result['imported_orders'] = importorders
				# if result['imported_orders'].length != 0
				# 	import_item = ImportItem.new
				# 	import_item.store_id = store.id
				# 	import_item.pervious_imported = result['imported_orders']['previous_imported']
				# 	import_item.success_imported = result['imported_orders']['success_imported']

				# end
				# import_items.save
			end
		end
		order_import_summaries = OrderImportSummary.all
		if !order_import_summaries.first.nil?
			order_import_summaries.first.status = 'completed'
			order_import_summaries.first.save
		end
	end
end