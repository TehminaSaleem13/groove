class ImportOrders
	def import_orders
		result = Hash.new
		# we will remove all the jobs pertaining to import which are not started

		# we will also remove all the import summary which are not started.
		if OrderImportSummary.where(status: 'in_progress').empty?
			order_import_summaries = OrderImportSummary.where(status: 'not_started')
			if !order_import_summaries.empty?
				order_import_summaries.each do |order_import_summary|
					if order_import_summary == order_import_summaries.first
						order_import_summary.status = 'in_progress'
						order_import_summary.save
						# add import item for each store
						@order_import_summary = order_import_summary
					elsif order_import_summary.status != 'in_progress'
						
						order_import_summary.delete

					end
				end
			end
			OrderImportSummary.where(status: 'completed').delete_all
			if !@order_import_summary.id.nil?
				stores = Store.where("status = '1' AND store_type != 'system'")
				if stores.length != 0	
					stores.each do |store|
						puts "store:" + store.inspect
						import_item = ImportItem.new
						if store.store_type == 'Amazon'
		      		context = Groovepacker::Store::Context.new(
		         	Groovepacker::Store::Handlers::AmazonHandler.new(store))
		       		result = context.import_orders
			       	import_item.store_id = store.id
			       	import_item.previous_imported = result[:previous_imported]
			       	import_item.success_imported = result[:success_imported]
			       	import_item.order_import_summary_id = @order_import_summary.id
			       	import_item.save
		     		elsif store.store_type == 'Ebay'
		       		context = Groovepacker::Store::Context.new(
		         	Groovepacker::Store::Handlers::EbayHandler.new(store))
		       		result = context.import_orders
		       		import_item.store_id = store.id
			       	import_item.previous_imported = result[:previous_imported]
			       	import_item.success_imported = result[:success_imported]
			       	import_item.order_import_summary_id = @order_import_summary.id
			       	import_item.save
			      elsif store.store_type == 'Magento1'
			      	context = Groovepacker::Store::Context.new(
		          Groovepacker::Store::Handlers::MagentoHandler.new(store))
			        result = context.import_orders.inspect
			      	import_item.store_id = store.id
			       	import_item.previous_imported = result[:previous_imported]
			       	import_item.success_imported = result[:success_imported]
			       	import_item.order_import_summary_id = @order_import_summary.id
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
					order_import_summary = OrderImportSummary.find(@order_import_summary.id)
					order_import_summary.status = 'completed'
					order_import_summary.save
				end
			end
		end	
		result
	end
end