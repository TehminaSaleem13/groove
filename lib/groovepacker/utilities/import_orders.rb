class ImportOrders
	def import_orders
		# @result = Hash.new
		# we will remove all the jobs pertaining to import which are not started

		# we will also remove all the import summary which are not started.
		order_import_summaries = OrderImportSummary.where(status: ['not_started','completed'])
		if !order_import_summaries.empty?
			order_import_summaries.each do |order_import_summary|
				if order_import_summary == order_import_summaries.first
					order_import_summary.status = 'in_progress'
					order_import_summary.save
					@id = order_import_summary.id
				end
				if order_import_summary.status != 'in_progress'
					order_import_summary.delete
				end
			end
		end
		ImportItems.delete_all
		stores = Store.where("status = '1' AND store_type != 'system'")
		if stores.length != 0	
			stores.each do |store|
				puts "store:" + store.inspect
				import_item = ImportItems.new
				if store.store_type == 'Amazon'
      		# context = Groovepacker::Store::Context.new(
        #  	Groovepacker::Store::Handlers::AmazonHandler.new(store))
       	# 	result = context.import_orders
       	# 	puts result.inspect
	       	import_item.store_id = store.id
	       	import_item.previous_imported = 10
	       	import_item.success_imported = 12
	       	import_item.order_import_summary_id = @id
	       	import_item.save
     		elsif store.store_type == 'Ebay'
       		# context = Groovepacker::Store::Context.new(
         # 	Groovepacker::Store::Handlers::EbayHandler.new(store))
       		# puts context.import_orders.inspect
       		import_item.store_id = store.id
	       	import_item.previous_imported = 5
	       	import_item.success_imported = 4
	       	import_item.order_import_summary_id = @id
	       	import_item.save
	      elsif store.store_type == 'Magento'
	      	import_item.store_id = store.id
	       	import_item.previous_imported = 14
	       	import_item.success_imported = 11
	       	import_item.order_import_summary_id = @id
	       	import_item.save
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