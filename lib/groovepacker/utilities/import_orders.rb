class ImportOrders
	def self.import_orders
		result = Hash.new
		# we will remove all the jobs pertaining to import which are not started

		# we will also remove all the import summary which are not started.
		order_import_summaries = OrderImportSummary.all
		order_import_summaries.each do |order_import_summary|
			if order_import_summary.status == 'not started'
				order_import_summary.delete
			end
		end

		result['stores'] = getactivestores
		if result['stores'].length != 0
			result['stores'].each do |store|
				result['imported_orders'] = importorders
				if result['imported_orders'].length != 0
					import_item = ImportItem.new
					import_item.store_id = store.id
					@import_item.pervious_imported = result['imported_orders']['previous_imported']
					@import_item.success_imported = result['imported_orders']['success_imported']

				end
				@import_items.save
			end
		end

	end
end