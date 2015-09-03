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
end
