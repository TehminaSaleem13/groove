class AddEmailAddressForReportOutOfStockToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :email_address_for_report_out_of_stock, :string, :default=>''
  end
end
