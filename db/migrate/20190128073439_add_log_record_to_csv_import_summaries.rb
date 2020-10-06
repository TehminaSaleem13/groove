class AddLogRecordToCsvImportSummaries < ActiveRecord::Migration[5.1]
  def change
    unless column_exists? :csv_import_summaries, :log_record
      add_column :csv_import_summaries, :log_record, :text, default: nil
    end
  end
end
