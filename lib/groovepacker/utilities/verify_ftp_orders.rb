# frozen_string_literal: true

class VerifyFtpOrders < Groovepacker::Utilities::Base
  def initiate_import_verification(tenant)
    stores = Store.joins(:ftp_credential).where('host IS NOT NULL and username IS NOT NULL and password IS NOT NULL and status=true and store_type = ? && ftp_credentials.use_ftp_import = ?', 'CSV', true)
    stores.each do |store|
      mapping = CsvMapping.find_by_store_id(store.id)
      next unless mapping.present? && mapping.order_csv_map.present? && store.try(:ftp_credential).try(:username) && store.try(:ftp_credential).try(:password) && store.try(:ftp_credential).try(:host)

      map = mapping.order_csv_map
      map.map[:map] = begin
                        map.map[:map].class == ActionController::Parameters ? map.map[:map].permit!.to_h : map.map[:map]
                      rescue StandardError
                        nil
                      end
      data = build_data(map, store)
      order_number_mapping = map.map[:map].key('name' => 'Order number', 'value' => 'increment_id')
      groove_ftp = FTP::FtpConnectionManager.get_instance(store, 'order')
      response = groove_ftp.download_imported(tenant)
      loop do
        break unless response[:status]

        if response[:status] && !order_number_mapping.nil?
          file_path = response[:file_info][:file_path]
          table = CSV.parse(File.read(file_path), headers: true)
          order_numbers = table.by_col[order_number_mapping.to_i].reject(&:nil?).uniq
          all_imported = true
          all_imported = false unless Order.where(increment_id: order_numbers).count == order_numbers.count
          groove_ftp.update_verified_status(response[:file_info][:ftp_file_name], all_imported)
        end
        response = groove_ftp.download_imported(tenant)
      end
    end
  end
end
