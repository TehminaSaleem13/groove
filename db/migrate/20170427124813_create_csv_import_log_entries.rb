class CreateCsvImportLogEntries < ActiveRecord::Migration[5.1]
  def change
    unless table_exists? :csv_import_log_entries
      create_table :csv_import_log_entries do |t|
        t.integer :index
        t.integer :csv_import_summary_id

        t.timestamps
      end
    end
  end
end
