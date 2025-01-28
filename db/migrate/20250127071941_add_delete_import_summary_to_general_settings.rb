class AddDeleteImportSummaryToGeneralSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :general_settings, :delete_import_summary, :boolean, :default => false
  end
end
