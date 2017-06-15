class CreateCsvImportLogEntries < ActiveRecord::Migration
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
