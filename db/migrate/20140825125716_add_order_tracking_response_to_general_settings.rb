class AddOrderTrackingResponseToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :tracking_error_order_not_found, :text
    add_column :general_settings, :tracking_error_info_not_found, :text
  end
end
