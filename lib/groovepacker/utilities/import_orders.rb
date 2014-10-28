	class ImportOrders
		def import_orders(tenant)
			Apartment::Tenant.switch(tenant)
			result = Hash.new
			# we will remove all the jobs pertaining to import which are not started

			# we will also remove all the import summary which are not started.
			if OrderImportSummary.where(status: 'in_progress').empty?
				order_import_summaries = OrderImportSummary.where(status: 'not_started')
				if !order_import_summaries.empty?
					ordered_import_summaries = order_import_summaries.order('updated_at' + ' ' + 'desc')
					ordered_import_summaries.each do |order_import_summary|
						if order_import_summary == ordered_import_summaries.first
							order_import_summary.status = 'in_progress'
							order_import_summary.save
							ImportItem.delete_all
							# add import item for each store
							stores = Store.where("status = '1' AND store_type != 'system'")
							if stores.length != 0	
								stores.each do |store|
									import_item = ImportItem.new
									import_item.store_id = store.id
									import_item.status = 'not_started'
									import_item.order_import_summary_id = order_import_summary.id
									import_item.save
								end
							end
							@order_import_summary = order_import_summary
						elsif order_import_summary.status != 'in_progress'	
							order_import_summary.delete
						end
					end
				end
				OrderImportSummary.where(status: 'completed').delete_all
				if !@order_import_summary.nil? && !@order_import_summary.id.nil?
					import_items = @order_import_summary.import_items
					import_items.each do |import_item|
						store_type = import_item.store.store_type
						store = import_item.store
						if store_type == 'Amazon'
							import_item.status = 'in_progress'
							import_item.save
							context = Groovepacker::Store::Context.new(
								Groovepacker::Store::Handlers::AmazonHandler.new(store,import_item))
							result = context.import_orders
							import_item.previous_imported = result[:previous_imported]
							import_item.success_imported = result[:success_imported]
							if !result[:status]
								import_item.status = 'failed'
							else
								import_item.status = 'completed'
							end 	
							import_item.save
						elsif store_type == 'Ebay'
							import_item.status = 'in_progress'
							import_item.save
							context = Groovepacker::Store::Context.new(
								Groovepacker::Store::Handlers::EbayHandler.new(store,import_item))
							result = context.import_orders
							import_item.previous_imported = result[:previous_imported]
							import_item.success_imported = result[:success_imported]
							if !result[:status]
								import_item.status = 'failed'
							else
								import_item.status = 'completed'
							end
							import_item.save
						elsif store_type == 'Magento'
							import_item.status = 'in_progress'
							import_item.save
							context = Groovepacker::Store::Context.new(
								Groovepacker::Store::Handlers::MagentoHandler.new(store,import_item))
							result = context.import_orders
							import_item.previous_imported = result[:previous_imported]
							import_item.success_imported = result[:success_imported]
							if !result[:status]
								import_item.status = 'failed'
							else
								import_item.status = 'completed'
							end
							import_item.save
						elsif store_type == 'Shipstation'
							import_item.status = 'in_progress'
							import_item.save
							context = Groovepacker::Store::Context.new(
								Groovepacker::Store::Handlers::ShipstationHandler.new(store,import_item))
							result = context.import_orders
							import_item.previous_imported = result[:previous_imported]
							import_item.success_imported = result[:success_imported]
							if !result[:status]
								import_item.status = 'failed'
							else
								import_item.status = 'completed'
							end
							import_item.save
						end
					end
					@order_import_summary.status = 'completed'
					@order_import_summary.save
				end
			end	
			result
		end
		def reschedule_job(type,tenant)
			Apartment::Tenant.switch(tenant)
			date = DateTime.now
			date = date + 1.day
			job_scheduled = false
			general_settings = GeneralSetting.all.first
			while !job_scheduled do
				should_schedule_job = false
				if type=='import_orders'
					should_schedule_job = general_settings.should_import_orders(date)
					time = general_settings.time_to_import_orders
				elsif type=='low_inventory_email'
					should_schedule_job = general_settings.should_send_email(date)
					time = general_settings.time_to_send_email
				end

				if should_schedule_job
					job_scheduled = general_settings.schedule_job(date,
						time, type)
				else
					date = date + 1.day
				end
			end	
		end
	end
