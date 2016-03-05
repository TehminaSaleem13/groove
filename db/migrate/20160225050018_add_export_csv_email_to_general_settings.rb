class AddExportCsvEmailToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :export_csv_email, :string
  end
end
