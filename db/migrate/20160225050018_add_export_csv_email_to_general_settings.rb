class AddExportCsvEmailToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :export_csv_email, :string
  end
end
