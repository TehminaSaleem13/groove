module SettingsHelper
  def zip_to_files(filename, data_object)
    require 'zip'
    temp_file = Tempfile.new(filename)
    begin
      Zip::OutputStream.open(temp_file) { |zos|}
      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|
        data_object.each do |ident, file|
          zip.add(ident.to_s+".csv", file)
        end
      end
      zip_data = File.read(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def import_orders_helper(tenant)
    Apartment::Tenant.switch(tenant)
    order_summary = OrderImportSummary.where(
      status: 'in_progress')

    if order_summary.empty?
      order_summary_info = OrderImportSummary.new
      order_summary_info.user_id = nil
      order_summary_info.status = 'not_started'
      order_summary_info.save
      # call delayed job
      import_orders_obj = ImportOrders.new
      # import_orders_obj.delay(:run_at => 1.seconds.from_now,:queue => 'importing orders').import_orders
      import_orders_obj.import_orders(tenant)
      import_orders_obj.reschedule_job('import_orders', tenant)
    end
  end

  def update_bulk_action(bulk_action_id, result)
    bulk_action = GrooveBulkActions.find_by_id(bulk_action_id)
    if bulk_action.present?
      bulk_action.cancel = true
      bulk_action.status = 'cancelled'
      bulk_action.save && result['bulk_action_cancelled_ids']
                          .push(bulk_action_id)
      # puts 'We saved the bulk action objects'
      # puts 'Error occurred while saving bulk action object'
    else
      result['error_messages'] = ['No bulk action found with the id.']
    end
  end
end
