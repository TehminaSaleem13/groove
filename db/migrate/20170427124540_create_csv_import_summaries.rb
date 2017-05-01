class CreateCsvImportSummaries < ActiveRecord::Migration
  def change
    create_table :csv_import_summaries do |t|
      t.string :file_name
      t.decimal :file_size,    :precision => 8, :scale => 4, :default => 0.0
      t.string :import_type

      t.timestamps
    end
  end
end
